json.screening_flags screening_flags do |screening_flag|
  json.category screening_flag.category
  json.label screening_flag.label
  json.message screening_flag.message
  json.keyword screening_flag.keyword
  json.destination_country_name screening_flag.destination_country_name
  json.denied_party_name screening_flag.denied_party_name
  json.denied_party_type screening_flag.denied_party_type
  json.source screening_flag.source
  json.screening_guidelines screening_flag.screening_guidelines
  json.operating_procedures screening_flag.operating_procedures
end
