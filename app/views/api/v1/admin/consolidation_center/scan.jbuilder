json.shipment do
  json.id @shipment.id
  json.easyship_shipment_id @shipment.easyship_shipment_id
  json.last_status_message_name @shipment.last_status_message_name
  json.items_description @shipment.item_descriptions
  json.courier_name @shipment.courier&.name
  json.destination_country_name @shipment.destination_country&.simplified_name
  json.consolidation_center_state @shipment.consolidation_center_state
  json.consolidation_center_events @shipment.consolidation_center_events
  json.allow_download_outbound_label @shipment.allow_download_outbound_label?
  json.allow_download_return_label @shipment.allow_download_return_label?
  json.outbound_label_url @shipment.label_url
  json.partial! "api/v1/admin/screening_flags/screening_flags", screening_flags: @shipment.screening_flags

  if params_include? "status_records"
    json.status_records @shipment.status_records do |status_record|
      json.created_at status_record.created_at
      json.scope status_record.status_message.scope&.titleize
      json.name status_record.status_message.name
      json.easyship_comments status_record.easyship_comments
      json.first_name status_record.user&.first_name
      json.last_name status_record.user&.last_name
    end
  end
end
