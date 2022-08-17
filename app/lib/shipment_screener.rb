class ShipmentScreener
  class TradeGovApiError < StandardError; end
  attr_accessor :shipment

  DEFAULT_SCREENING_CRITERIA = [:denied_party, :dangerous_goods, :prohibited_goods, :prohibited_goods_by_courier].freeze
  TRADE_GOV_API_URL = "https://data.trade.gov/consolidated_screening_list/v1/search".freeze

  def initialize(options = {})
    @shipment = options[:shipment]
    @origin_country_alpha2 = @shipment.origin_country.alpha2
    @destination_country_alpha2 = @shipment.destination_country.alpha2
    @destination_country_name = @shipment.destination_country.simplified_name
    @keyword_lists = ScreeningKeyword.keyword_lists(origin_country_alpha2: @origin_country_alpha2, destination_country_alpha2: @destination_country_alpha2)
    @screen_for = options[:screen_for] || DEFAULT_SCREENING_CRITERIA
  end

  def process
    @screen_for.each { |category| send("screen_for_#{category}") }
  end

  private

  def screen_for_dangerous_goods
    screen_for_goods_type("dangerous_goods", @keyword_lists["dangerous_goods"])
  end

  def screen_for_prohibited_goods
    screen_for_goods_type("prohibited_goods", @keyword_lists["prohibited_goods"])
  end

  def screen_for_goods_type(category, goods_list)
    matched_combinations = matched_combinations_for(goods_list)
    return if matched_combinations.blank?

    matched_combinations&.each do |matched_combination|
      shipment.screening_flags.build(
        category: category,
        keyword: matched_combination["keyword"],
        destination_country_name: (@destination_country_name if matched_combination["destination_country_alpha2"] == @destination_country_alpha2),
        screening_guidelines: matched_combination["screening_guidelines"],
        operating_procedures: matched_combination["operating_procedures"]
      )
    end
  end

  def screen_for_prohibited_goods_by_courier
    @keyword_lists["prohibited_goods_by_courier"].each do |courier_admin_name, goods_list|
      add_prohibited_courier(courier_admin_name) if matched_combinations_for(goods_list).any?
    end
  end

  def add_prohibited_courier(courier_admin_name)
    shipment.order_data ||= {}
    shipment.order_data["couriers_excluded_due_to_prohibited_goods"] ||= []
    shipment.order_data["couriers_excluded_due_to_prohibited_goods"] << courier_admin_name
  end

  def matched_combinations_for(goods_list)
    keyword_names = goods_list.keys

    matched_keywords(keyword_names).map do |keyword|
      (goods_list[keyword] || goods_list[keyword.singularize]).merge("keyword" => keyword)
    end
  end

  def matched_keywords(keyword_names)
    return [] unless keyword_names.any?

    list = keyword_names
      .flat_map { |word| [word, word.pluralize] }
      .uniq
      .join("|")

    item_descriptions.map { |description| description.scan(/\b(?:#{list})\b/) }.flatten.compact.uniq
  end

  def item_descriptions
    @_item_descriptions ||= @shipment.shipment_items.map(&:description).uniq.compact
  end

  def screen_for_denied_party
    return unless contains_denied_receiver?

    denied_party_names&.each do |denied_party_name|
      shipment.screening_flags.build(
        category: "denied_party",
        denied_party_name: denied_party_name,
        denied_party_type: "receiver",
        source: denied_party_sources.join(", ")
      )
    end
  end

  def contains_denied_receiver?
    headers = {"subscription-key" => ENV["TRADE_GOV_SUBSCRIPTION_KEY"]}

    query = {
      sources: nil,
      name: shipment.destination_name,
      fuzzy_name: true
    }

    @trade_gov_response = HTTParty.get(TRADE_GOV_API_URL, headers: headers, query: query, timeout: 1)
    raise TradeGovApiError, @trade_gov_response.parsed_response unless @trade_gov_response.success?

    @trade_gov_response.parsed_response["total"]&.> 0
  rescue Net::ReadTimeout, Net::OpenTimeout, TradeGovApiError => e
    ErrorNotification.notify(e)
    false
  end

  def denied_party_names
    @trade_gov_response.parsed_response["results"].map { |result| result["name"] }.uniq
  end

  def denied_party_sources
    @trade_gov_response.parsed_response["results"].map { |result| result["source"] }.uniq
  end
end
