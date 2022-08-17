class CreateConsolidationCenters < ActiveRecord::Migration[6.0]
  def change
    create_table :consolidation_centers do |t|

      t.timestamps
    end
  end
end
