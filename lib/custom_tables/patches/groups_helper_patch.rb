module CustomTables
	module Patches
		module GroupsHelperPatch
			module Prepend extend ActiveSupport::Concern
				def prepended(base)
					base.extend(ClassMethods)
				end

				def group_settings_tabs(group)
			    tabs = super(group)
			    tabs << {:name => 'table_memberships', :partial => 'table_permissions/tab_group_edit', :label => :label_custom_tables}
			    tabs
			  end
			end
		end
	end
end

GroupsHelper.send :prepend, CustomTables::Patches::GroupsHelperPatch::Prepend unless GroupsHelper.included_modules.include?(CustomTables::Patches::GroupsHelperPatch::Prepend)