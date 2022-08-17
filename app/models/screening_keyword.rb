class ScreeningKeyword < ActiveRecord::Base
    class << self
    def parse_data
      screening_keywords = ScreeningKeywordsFetcher.fetch_all
      created_count = ScreeningKeyword.import(screening_keywords, batch_size: 1000).ids.size
      deleted_count = ScreeningKeyword.where("updated_at < ?", 1.minute.ago).delete_all
      Rails.cache.delete_matched("screening_keywords_list/*")
      {created: created_count, deleted: deleted_count, updated_flags: update_recent_flags}
    end

    def update_recent_flags
      updated_flags = 0
      keywords_to_update = ScreeningKeyword.where("(screening_guidelines IS NOT NULL OR operating_procedures IS NOT NULL) AND courier_admin_name IS NULL")
      keywords_to_update.each do |kw|
        flags_to_update = ScreeningFlag.where("created_at > ?", 1.month.ago).where(
          category: kw.category,
          keyword: [kw.keyword, kw.keyword.pluralize],
          destination_country_name: Country.find_by(alpha2: kw.destination_country_alpha2)&.simplified_name
        )
        updated_flags += flags_to_update.update_all(screening_guidelines: kw.screening_guidelines, operating_procedures: kw.operating_procedures, updated_at: Time.zone.now)
      end
      updated_flags
    end

    def keyword_lists(origin_country_alpha2:, destination_country_alpha2:)
      cache_key = ["screening_keywords_list", origin_country_alpha2, destination_country_alpha2]
      Rails.cache.fetch(cache_key, expires_in: 1.day) do
        get_keyword_lists(origin_country_alpha2: origin_country_alpha2, destination_country_alpha2: destination_country_alpha2)
      end
    end

    def fetch(origin_country_alpha2:, destination_country_alpha2:)
      where("origin_country_alpha2 IS NULL OR origin_country_alpha2 = ?", origin_country_alpha2)
        .where("destination_country_alpha2 IS NULL OR destination_country_alpha2 = ?", destination_country_alpha2)
    end

    def get_keyword_lists(origin_country_alpha2:, destination_country_alpha2:)
      list = fetch(origin_country_alpha2: origin_country_alpha2, destination_country_alpha2: destination_country_alpha2)

      prohibited_goods_by_courier, prohibited_goods, dangerous_goods  = [], [], []
      list.each do |r|
        if r.courier_admin_name.present? &&  r.category == "prohibited_goods"
          prohibited_goods_by_courier << r
        elsif r.category == "prohibited_goods"
          prohibited_goods << r
        elsif r.category == "dangerous_goods"
          dangerous_goods << r
        end
      end

      lists = {
        "dangerous_goods" => rejected_goods(dangerous_goods),
        "prohibited_goods" => rejected_goods(prohibited_goods),
        "prohibited_goods_by_courier" => {}
      }

      prohibited_goods_by_courier.select { |r| r.category == "prohibited_goods" }.group_by(&:courier_admin_name).each do |courier_admin_name, courier_list|
        lists["prohibited_goods_by_courier"][courier_admin_name] = rejected_goods(courier_list)
      end

      lists
    end

    def rejected_goods(list)
      forbidden, allowed = list.partition { |r| r.permission == "forbidden" }
      allowed_keywords = allowed.pluck(:keyword)
      forbidden.reject! { |r| allowed_keywords.include?(r.keyword) }

      forbidden.inject({}) do |final_list, r|
        final_list[r.keyword.downcase] = r.attributes.slice("destination_country_alpha2", "screening_guidelines", "operating_procedures").compact
        final_list
      end
    end
  end
end
