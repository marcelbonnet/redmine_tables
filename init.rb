Redmine::Plugin.register :glad_custom_tables do
  name 'Glad Custom Tables plugin'
  author 'Ivan Marangoz'
  description 'This is a plugin for Redmine'
  version '0.0.1'


  menu :project_menu, :custom_tables, {controller: 'custom_tables', action: 'index'}, caption: :glad_custom_tables, param: :project_id

  #menu :application_menu, :glad_custom_tables, {controller: 'custom_tables', action: 'index'}, caption: :glad_custom_tables

   project_module :glad_custom_tables do
     permission :show_tables, {
       custom_tables: [:index, :show],
       custom_entities: [:index, :show, :context_menu]
     }, global: true

     permission :manage_entities, {
       custom_tables: [:index, :show],
       custom_entities: [:index, :show, :new, :edit, :create, :update, :destroy, :context_menu, :bulk_edit, :bulk_update, :add_belongs_to, :new_note, :context_export],
       table_fields: [:index, :show]
     }, global: true

     permission :manage_tables, {
       custom_tables: [:index, :show, :new, :edit, :create, :update, :destroy],
       custom_entities: [:index, :show, :new, :edit, :create, :update, :destroy, :context_menu, :bulk_edit, :bulk_update],
       table_fields: [:index, :show, :new, :edit, :create, :update, :destroy]
     }, global: true
   end

  #CustomFieldsHelper::CUSTOM_FIELDS_TABS << {name: 'CustomTableCustomField', partial: 'custom_fields/index', label: :label_glad_custom_tables}
end
require 'glad_custom_tables'