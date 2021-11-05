module CustomTables
	module Patches
		module RolePatch
			module Included extend ActiveSupport::Concern
				def self.included(base)
					base.class_eval do

						# FIXME: acho que não preciso disso: são role gerenciados por usuários não administradores.
						# has_and_belongs_to_many :managed_roles, :class_name => 'Role',
						#    :join_table => "#{table_name_prefix}roles_managed_roles#{table_name_suffix}",
						#    :association_foreign_key => "managed_role_id"

						has_many :table_member_roles, :dependent => :destroy
						has_many :table_members, :through => :table_member_roles
					end
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

Role.send :include, CustomTables::Patches::RolePatch::Included unless Role.included_modules.include?(CustomTables::Patches::RolePatch::Included)