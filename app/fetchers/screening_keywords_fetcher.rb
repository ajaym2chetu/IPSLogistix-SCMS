class ScreeningKeywordsFetcher
  GOOGLE_SHEETS_FILE_NAME = "screening_keywords".freeze # file to be uploaded to Google Sheet

  class << self
    def fetch_all
      clear_file_instructions(keyword_list).uniq
    end

    private

    def clear_file_instructions(list)
      list.reject { |row| row["category"].start_with?("[instructions] ") }
    end

    def keyword_list
      CSV.parse(
        GoogleSheetFetcher.new(spreadsheet_id).fetch,
        headers: true
      ).map { |row| row.to_h.merge("keyword" => row["keyword"]) }
    end

    def spreadsheet_id
      GoogleSheet.find_by(name: GOOGLE_SHEETS_FILE_NAME).file_id
    end
  end
end
