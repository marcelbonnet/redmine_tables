require 'redmine'

Redmine::Plugin.register :redmine_tables do
  name 'Redmine Tables'
  author 'Marcel Bonnet'
  description 'Create custom Tables, granting permissions and creating workflows. It is compatible with Redmine Custom Workflows plugin too.'
  version '1.1.0'
  requires_redmine :version_or_higher => '3.4.0'
  url 'https://github.com/marcelbonnet/redmine_tables'
  author_url 'https://github.com/marcelbonnet'

  permission :view_table_rows, {
    custom_entities: [:show, :context_menu],
    custom_tables: [:show]
  }

  permission :add_table_row, {
      custom_entities: [:new, :create],
  }

  permission :edit_table_row, {
      custom_entities: [:edit, :update],
  }

  permission :delete_table_row, {
      custom_entities: [:destroy],
  }

  permission :upload_csv_to_table, {
      custom_entities: [:new, :create, :upload],
      custom_tables: [:csv_example],
  }

  permission :table_bulk_edit, {
      custom_entities: [:bulk_edit, :bulk_update],
  }

  Redmine::FieldFormat::UserFormat.customized_class_names << 'CustomEntity'

  if Redmine::Plugin.installed?(:redmine_custom_workflows)
    requires_redmine_plugin :redmine_custom_workflows, :version_or_higher => '1.0.5'
    CustomWorkflow::OBSERVABLES.push(:custom_entity)
    CustomWorkflow::SINGLE_OBSERVABLES.push(:custom_entity)
    require "redmine_custom_workflows/patches/custom_entity_patch"
  end

end


Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :custom_tables, :custom_tables_path, caption: :label_custom_tables,
            :html => {:class => 'icon icon-package'}
end

Dir[File.join(File.dirname(__FILE__), '/lib/custom_tables/**/*.rb')].each { |file| require_dependency file }