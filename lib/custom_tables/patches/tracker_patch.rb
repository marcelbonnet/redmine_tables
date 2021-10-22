module CustomTables
	module Patches
		module TrackerPatch

			def self.included(base)
				base.class_eval do

					has_and_belongs_to_many :custom_entity_custom_fields, :class_name => 'CustomEntityCustomField',
                          :join_table => "#{table_name_prefix}custom_entity_custom_fields_trackers#{table_name_suffix}",
                          :association_foreign_key => 'custom_entity_id'
				end
			end
		
		end
	end
end

Tracker.send(:include, CustomTables::Patches::TrackerPatch) unless Tracker.included_modules.include?(CustomTables::Patches::TrackerPatch)