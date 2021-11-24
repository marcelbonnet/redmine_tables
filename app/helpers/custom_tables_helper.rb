module CustomTablesHelper

  # usado em views/custom_tables/index.html.erb
  def render_custom_table_content(column, entity)
    value = column.value_object(entity)
    if value.is_a?(Array)
      value.collect {|v| send("#{entity.class.name.underscore}_column_value", column, entity, v)}.compact.join(', ').html_safe
    else
      if entity.is_a? CustomEntity
        custom_entity_column_value column, entity, value
      else
        custom_table_column_value column, entity, value
      end
    end
  end

  def custom_table_column_value(column, entity, value)
    case column.name
    when :name
      link_to value, custom_table_path(entity)
    else
      format_object(value)
    end
  end

  def custom_entity_column_value(column, custom_entity, custom_value)
    return format_object(custom_value) unless custom_value.is_a? CustomValue
    value = custom_value.value
    case column.custom_field.field_format
    when 'belongs_to'
      if value.present? && custom_value.custom_entity_id
        link_to value, custom_entity_path(custom_value.custom_entity_id)
      else
        value || '---'
      end
    when 'bool'
      if custom_value.true?
        l(:general_text_Yes)
      else
        l(:general_text_No)
      end
    when 'date'
      if value.present?
        Date.parse(value).strftime(Setting.date_format)
      else
        '---'
      end
    else
      if custom_entity.main_custom_field.id == column.custom_field.id # If main custom value
        link_to value, custom_entity_path(custom_entity)
      else
        format_object(value)
      end
    end
  end

  # @param [String|Array] permissions One symbol or an array of symbols.
  # @param [CustomEntity|Array] entity One object or array of objects.
  # @param [Issue] issue An Issue to check its status. User is not allowed if IssueStatus is closed.
  # @param [Boolean] skip_workflow Skips workflow rules and focus on issue status (closed or not) and user's permissions. Defaults to false.
  # @param [CustomTable] table
  # @param [Integer] match_type one of Group::TABLE_PERMISSION_MATCH_ANY | Group::TABLE_PERMISSION_MATCH_ALL
  def is_user_allowed_to_table?(permissions, entity:nil, issue:nil, skip_workflow:false, table:nil , match_type: Group::TABLE_PERMISSION_MATCH_ANY)
    user=User.current
    return true if user.admin?
    result = true

    # ##############################
    # Check based on Entity
    # ##############################
    if entity
      if entity.is_a?Array
        entities = CustomEntity.find(entity)
      else
        entities = Array(entity)
      end
      
      result = false if entities.collect{|ent|
        if skip_workflow
          ent.try(:issue).try(:closed?)
        else
          ent.workflow_rule_by_attribute.select {|attr, rule| rule != 'readonly'}.keys.size == 0 or ent.try(:issue).try(:closed?) # para não editar via página administrativa
        end
      }.any?(true)
    end

    # ##############################
    # Check based on IssueStatus
    # ##############################

    result = false if issue.try(:closed?) # @issue class variable is present if the table is related to an Issue. We must disallow the user if the issue is closed.

    # ##############################
    # Check based on permissions
    # ##############################

    permissions = [permissions] unless permissions.is_a?(Array)
    
    unless @issue.nil?
      result &= permissions.collect{|perm|  
          user.allowed_to?(perm, @issue.project)
      }.any?(true)
    end

    # ##############################
    # Check based TableMember (no issue)
    # ##############################
    if @issue.nil? && !table.nil?
      # result &= entities.collect{|ent|
      #   user.groups.map{|group| group.has_table_permissions?(permissions, ent.custom_table, match_type)}
      # }.any?(true)
      result &= user.groups.map{|group| group.has_table_permissions?(permissions, table, match_type) }.any?(true) if table.projects.size == 0
    end

    result
  end

  # helper to change the behavior of an icon depending on issue status for an admin user
  def admin_icon(selector, entity)
    selector << "-admin" if User.current.admin? && entity.try(:issue).try(:closed?)
    selector
  end

  def admin_l(user_label, admin_label, entity)
    label = l(user_label)
    label = l(admin_label) if User.current.admin? && entity.try(:issue).try(:closed?)
    label
  end

end
