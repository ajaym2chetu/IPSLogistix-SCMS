class ConsolidationCenter < ActiveHash::Base
  self.data = [
    {
      id: 1, 
      admin_name: "test",
      old_admin_name: "test",
      location: "test",
      facility: "test",
      address: {
        line_1: "test",
        line_2: "test",
        city: "test",
        postal_code: "test",
        state: "test",
        country_name: "test",
        country_alpha2: "test",
        country_alpha3: "test",
        contact_name: "test",
        contact_email: "test",
        contact_phone: "test",
        company_name: "test"
      }
    }
  ]

  class << self
    def admin_names
      @_admin_names ||= all.map(&:admin_name)
    end

    def old_admin_names
      @_old_admin_names ||= all.map(&:old_admin_name)
    end

    def find_by_string(str)
      return if str.blank?
      find_by(admin_name: str) || find_by(old_admin_name: str)
    end
  end
end
