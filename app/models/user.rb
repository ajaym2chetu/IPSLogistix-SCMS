# => user model
class User < ActiveRecord::Base
  has_secure_password validations: false
  has_secure_token :access_token

  validates :email, presence: true

  def self.find_detail(user)
    data = User.select(:id,:access_token,:first_name,:last_name,:email).where(id:user.id)
    return data
  end
end
