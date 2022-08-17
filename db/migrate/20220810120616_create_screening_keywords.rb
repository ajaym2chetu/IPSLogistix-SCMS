class CreateScreeningKeywords < ActiveRecord::Migration[6.0]
  def change
    create_table :screening_keywords do |t|
      t.string :category
      t.string :permission
      t.string :origin_country_alpha2
      t.string :destination_country_alpha2
      t.string :courier_admin_name
      t.string :keyword
      t.string :screening_guidelines
      t.string :operating_procedures

      t.timestamps
    end
  end
end
