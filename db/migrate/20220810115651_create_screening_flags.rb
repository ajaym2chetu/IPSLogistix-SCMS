class CreateScreeningFlags < ActiveRecord::Migration[6.0]
  def change
    create_table :screening_flags do |t|
      t.string :category
      t.string :label
      t.string :message
      t.string :destination_country_name
      t.string :denied_party_name
      t.string :denied_party_type
      t.string :source
      t.string :screening_guidelines
      t.string :operating_procedures

      t.timestamps
    end
  end
end
