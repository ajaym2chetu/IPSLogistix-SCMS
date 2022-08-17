class GoogleSheetFetcher
  AUTHED_SCOPE = [
    Google::Apis::DriveV3::AUTH_DRIVE_READONLY
  ]

  GOOGLE_API_ERRORS = [
    Google::Apis::ServerError,
    Google::Apis::ClientError,
    Google::Apis::AuthorizationError
  ]

  def initialize(file_id)
    @file_id = file_id
    @client = initialize_client
  end

  def fetch
    @client.export_file(@file_id, "text/csv", download_dest: StringIO.new)
  rescue *GOOGLE_API_ERRORS => e
    ErrorNotification.notify(e)
  end

  private

  def initialize_client
    client = Google::Apis::DriveV3::DriveService.new
    client.authorization = Google::Auth.get_application_default(AUTHED_SCOPE)
    client
  rescue => e
    ErrorNotification.notify(e)
  end
end
