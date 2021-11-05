class AddTableToGroup < ActiveRecord::Migration[5.2]
  def change
    create_table :custom_tables_groups, id: false do |t|
      t.belongs_to :custom_table
      t.belongs_to :group
    end

    create_table :table_members do |t|
      t.belongs_to :user
      t.belongs_to :custom_table
      t.datetime :created_on, null: false
    end

    create_table :table_member_roles do |t|
      t.belongs_to :table_member
      t.belongs_to :role
      t.integer :inherited_from
    end

    add_column :custom_tables, :status, :integer, default: 1, null: false

  end
end
