class AddCecfToTracker < ActiveRecord::Migration[5.2]
  def change
    create_table :custom_entity_custom_fields_trackers, id: false do |t|
      t.belongs_to :custom_entity
      t.belongs_to :tracker
    end

  end
end
