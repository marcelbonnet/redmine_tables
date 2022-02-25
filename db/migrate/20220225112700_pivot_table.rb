class PivotTable < ActiveRecord::Migration[5.2]
  def change
    add_column :custom_tables, :max_rows, :integer, null: true
    add_column :custom_tables, :pivot, :boolean, default: false, null: false
  end
end
