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


			  TABLE_PERMISSION_MATCH_ANY = 1
			  TABLE_PERMISSION_MATCH_ALL = 2

			  # General permission check. It does not care about
			  # Table Workflows and/or Issue Workflows (open/closed), if any.
			  # It only checks if a Group is a TableMember
			  # and has permissions (Role) to some Table.
			  # Params:
			  # => permissions: symbol or array of symbols
			  # => table: object or id
			  # => match_type: TABLE_PERMISSION_MATCH_ANY | TABLE_PERMISSION_MATCH_ALL , when the parameter "permissions" is an Array
			  def has_table_permissions?(permissions, table, match_type=TABLE_PERMISSION_MATCH_ANY)
			  	member = TableMember::find_or_new(table, self) # object or id
			  	return false if member.id.nil?
			  	permissions = [permissions] unless permissions.is_a?(Array)
			    result = permissions.collect{|perm|  
			    	if match_type == TABLE_PERMISSION_MATCH_ANY
			      	member.roles.map{|r| r.has_permission?(perm) }.any?(true)
			      elsif match_type == TABLE_PERMISSION_MATCH_ALL
			      	member.roles.map{|r| r.has_permission?(perm) }.reduce(:&)
			      else
			      	false
			      end
			    }
			    result = result.any?(true) if match_type == TABLE_PERMISSION_MATCH_ANY
			    result = result.reduce(:&) if match_type == TABLE_PERMISSION_MATCH_ALL	
			    result
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