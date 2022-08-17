class ScreeningFlag < ActiveRecord::Base
    DEFAULT_LABELS = {
    "denied_party" => "Hold",
    "dangerous_goods" => "Inspection",
    "prohibited_goods" => "Inspection",
    "custom" => "Good"
  }.freeze

  belongs_to :shipment
  before_validation :set_defaults

  validates :category, presence: true, inclusion: {in: DEFAULT_LABELS.keys, message: "%{value} is not a valid label"}
  validates :label, presence: true, inclusion: {in: DEFAULT_LABELS.values, message: "%{value} is not a valid label"}
  validates :denied_party_type, presence: true, inclusion: {in: %w[sender receiver], message: "%{value} is not a valid label"}, if: -> { denied_party_name.present? }

  def set_defaults
    self.label ||= DEFAULT_LABELS[category]
    self.message ||= [keyword, denied_party_name, destination_country_name].reject(&:blank?).join(" / ")
  end
end
