module WorkflowTable

  # @params [CustomTable] table A CustomTable
  # @params [Integer] issue_id The Issue ID
  # @params [Integer] num_new_rows number of new rows
  # Checks if table allows more rows to be added.
  def table_allows_more_rows?(table, issue_id, num_new_rows=1)
    if CustomEntity.where(custom_table_id:table.id, issue_id:issue_id).size + num_new_rows > table.max_rows.to_i && !table.max_rows.nil?
      false
    else
      true
    end
  end


	# @params [Symbol|Array] permissions Valid symbols.
	def is_user_allowed_to_table?(permissions, table, table_member_match_type=Group::TABLE_PERMISSION_MATCH_ANY)
		user=User.current
    return true if user.admin?
    result = true

    permissions = [permissions] unless permissions.is_a?(Array)

    table = CustomTable.find(table.to_i) if table.is_a?Integer or table.is_a?String

    if @issue.nil? # View was reached through route /custom_tables/[:id]
    	if permissions.size == 0 && permissions.include?(:view_table_rows)
    		# user is allowed to access the view. But the view will be responsible to check for permissions on each row
	    	result &= true
	    end
    else
    	if table.projects.size > 0
    		# Project Members
    		result &= permissions.collect{|perm|  
          user.allowed_to?(perm, @issue.project)
      }.any?(true)
    	else
    		# Table Members
    		result &= user.groups.map{|group| group.has_table_permissions?(permissions, table, table_member_match_type) }.any?(true)
    	end
    	result = false if @issue.try(:closed?) && permissions.include?(:add_table_row)
    end
    result
	end


	# @param [String|Array] permissions :view_table_rows, :delete_table_row should be checked separately, because they ignore Workflow.
	# @param [CustomEntity|Array] entity
	# @param [Integer] table_member_match_type defaults to 
	# Group::TABLE_PERMISSION_MATCH_ANY. Applies when checking against a table 
	# unrelated to a Project, when TableMember is used.
	def is_user_allowed_to_row?(permissions, entity, table_member_match_type=Group::TABLE_PERMISSION_MATCH_ANY)
		# entity, issue: pode ter ou não uma issue
		# se bulke edit, o mesmo problema mas é um array de entidades
		# para checar por delete, preciso skip_workflow pq o workflow pode estar fechado para edição. Só vou ver se a issu está aberta/fechada
    user=User.current
    return true if user.admin?
    result = true

    if entity.is_a?Array
      entities = CustomEntity.find(entity)
    else
      entities = Array(entity)
    end
		    
    # ##############################
    # Permissions
    # ##############################
    permissions = [permissions] unless permissions.is_a?(Array)

    issues = Array(@issue)
    issues = entities.collect{|ent| ent.issue} if @issue.nil?

    if issues.any?
			# Project Member
      result &= permissions.collect{|perm|  
          issues.collect{|i| user.allowed_to?(perm, i.project)}
      }.flatten.any?(true)
  	else
    	# Table Member
    	result &= user.groups.map{|group| 
    		entities.collect{|ent|
   				group.has_table_permissions?(permissions, ent.custom_table, table_member_match_type) if ent.custom_table.projects.size == 0
    		}
    	}.flatten.any?(true)
    end

    # ##############################
    # Workflow w/o an Issue
    # ##############################
    if not permissions.include?(:view_table_rows) and not permissions.include?(:delete_table_row)
    	result = false if entities.collect{|ent|
      	ent.workflow_rule_by_attribute.select {|attr, rule| rule != 'readonly'}.keys.size == 0 or ent.try(:issue).try(:closed?) # para não editar via página administrativa
    	}.any?(true)
  	end

		# ##############################
    # delete perm: workflow check 
    # is not enough if @issue exists
    # ##############################
    result = false if permissions.include?(:delete_table_row) && issues.collect{|i| i.try(:closed?)}.any?(true) # @issue class variable is present if the table is related to an Issue. We must disallow the user if the issue is closed.
   

    result
	end

	
end