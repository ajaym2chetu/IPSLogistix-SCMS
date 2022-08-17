json.shipments @shipments do |shipment|
  json.id shipment.id
  json.easyship_shipment_id shipment.easyship_shipment_id
  json.order_number shipment.get_order_number
  json.last_status_message_name shipment.last_status_message_name
  json.courier_name shipment.courier&.name
  json.destination_country_name shipment.destination_country.name
  json.destination_name shipment.destination_name
  json.items_description shipment.item_descriptions&.join(", ")
  json.total_customs_value shipment.total_customs_value&.to_f
  json.currency shipment.currency
end
