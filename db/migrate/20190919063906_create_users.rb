class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :access_token
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :verify_email, :comment => "1 for verify",:default => "0"
      t.string :password_digest
      t.string :country_code
      t.string :mobile_number
      t.string :otp
      t.string :verify_mobile, :comment => "1 for verify",:default => "0"
      t.timestamps
    end 
  end
end
