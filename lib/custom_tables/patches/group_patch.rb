module CustomTables
	module Patches
		module GroupPatch
			module Included extend ActiveSupport::Concern
				def self.included(base)
					base.class_eval do
						has_and_belongs_to_many :custom_tables, :class_name => 'CustomTable',
                          :join_table => "#{table_name_prefix}custom_tables_groups#{table_name_suffix}",
                          :association_foreign_key => 'custom_table_id'

						has_many :table_members, :foreign_key => 'user_id', :dependent => :destroy

						has_many :table_memberships,
							lambda { joins(:custom_table).where.not(:custom_tables => {:status => CustomTable::STATUS_ARCHIVED} ) },
							:class_name => "TableMember",
							:foreign_key => "user_id"
					end
				end

				# Returns true if the group is a member of table
			  def member_of_table?(table)
			    table.is_a?(CustomTable) && table_member_ids.include?(table.id)
			  end

			end

			# module Prepend extend ActiveSupport::Concern
			# 	def prepended(base)
			# 		base.extend(ClassMethods)
			# 	end
			# end
		end
	end
end

Group.send :include, CustomTables::Patches::GroupPatch::Included unless Group.included_modules.include?(CustomTables::Patches::GroupPatch::Included)