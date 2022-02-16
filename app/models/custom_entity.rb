class CustomEntity < ActiveRecord::Base
  include Redmine::SafeAttributes
  include CustomTables::ActsAsJournalize

  belongs_to :custom_table
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  belongs_to :issue
  has_one :project, through: :issue
  has_many :custom_fields, through: :custom_table

  safe_attributes 'custom_table_id', 'author_id', 'custom_field_values', 'custom_fields', 'parent_entity_ids',
                  'sub_entity_ids', 'issue_id', 'external_values'

  acts_as_customizable
  acts_as_attachable

  delegate :main_custom_field, to: :custom_table

  acts_as_watchable

  self.journal_options = {}

  validate :validate_required_fields


  def name
    if new_record?
      custom_table.name
    else
      custom_value = custom_values.detect { |cv| cv.custom_field == custom_table.main_custom_field }
      custom_value.try(:value) || '---'
    end
  end

  def editable?(user = User.current)
    return true if user.admin? || custom_table.is_for_all
    return user.allowed_to?(:edit_issues, issue.project) unless issue.nil?
    return user.groups.map{|group| group.has_table_permissions?(:edit_table_row, custom_table, Group::TABLE_PERMISSION_MATCH_ANY) }
  end

  def visible?(user = User.current)
    return user.allowed_to?(:view_table_rows, nil, global: true) unless issue.nil?
    return user.groups.map{|group| group.has_table_permissions?(:view_table_rows, custom_table, Group::TABLE_PERMISSION_MATCH_ANY) }
  end

  def deletable?(user = User.current)
    return editable? unless issue.nil?
    return user.groups.map{|group| group.has_table_permissions?(:delete_table_row, custom_table, Group::TABLE_PERMISSION_MATCH_ANY) }
  end

  def leaf?
    false
  end

  def is_descendant_of?(p)
    false
  end

  def each_notification(users, &block)
  end

  def notified_users
    []
  end

  def attachments
    []
  end

  def available_custom_fields
    custom_fields.sorted.to_a
  end

  def created_on
    created_at
  end

  def updated_on
    updated_at
  end

  def value_by_external_name(external_name)
    custom_field_values.detect {|v| v.custom_field.external_name == external_name}.try(:value)
  end

  def external_values=(values)
    custom_field_values.each do |custom_field_value|
      key = custom_field_value.custom_field.external_name
      next unless key.present?
      if values.has_key?(key)
        custom_field_value.value = values[key]
      end
    end
    @custom_field_values_changed = true
  end

  def to_h
    values = {}
    custom_field_values.each do |value|
      values[value.custom_field.external_name] = value.value if value.custom_field.external_name.present?
    end
    values["id"] = id
    values
  end

  # Validates the fields against "required" workflow requirements
  def validate_required_fields
    # ignore if there is no project to get the user Roles
    return if self.try(:issue).try(:project).nil?
    user = new_record? ? author : current_journal.try(:user)

    required_attribute_names(user).each do |attribute|
      attribute = attribute.to_i
      v = custom_field_values.detect {|v| v.custom_field_id == attribute}
      if v && Array(v.value).detect(&:present?).nil?
        errors.add(v.custom_field.name, l('activerecord.errors.messages.blank'))
      end
    end
  end


  # Returns a hash of the workflow rule by attribute for the given user
  #
  # Examples:
  #   custom_entity.workflow_rule_by_attribute # => {'123' => 'required', '124' => 'readonly', '125' => ''}
  def workflow_rule_by_attribute(user=nil)
    if issue.nil?
      result = {}
      custom_fields.map{|cf|
        perm = cf.editable?? (cf.is_required?? 'required' : '') : 'readonly'
        result[cf.id.to_s] = perm
      }
      return result
    end

    user_real = user || User.current
    roles = user_real.admin ? Role.all.to_a : user_real.roles_for_project(issue.project)
    roles = roles.select(&:consider_workflow?)
    return {} if roles.empty?

    result = {}
    workflow_permissions =
      WorkflowPermission.where(
        :tracker_id => issue.tracker_id, :old_status_id => issue.status_id,
        :role_id => roles.map(&:id)
      ).to_a
    if workflow_permissions.any?
      workflow_rules = workflow_permissions.inject({}) do |h, wp|
        h[wp.field_name] ||= {}
        h[wp.field_name][wp.role_id] = wp.rule
        h
      end

      # ######################
      # fields invisíveis
      fields_with_roles = {}

      # não tenho nenhum com visible=false
      CustomEntityCustomField.where(:visible => false).
        joins(:roles).pluck(:id, "role_id").
          each do |field_id, role_id|
        fields_with_roles[field_id] ||= []
        fields_with_roles[field_id] << role_id
      end

      roles.each do |role|
        fields_with_roles.each do |field_id, role_ids|
          unless role_ids.include?(role.id)
            field_name = field_id.to_s
            workflow_rules[field_name] ||= {}
            workflow_rules[field_name][role.id] = 'readonly'
          end
        end
      end
      # fields invisíveis fim
      # ######################
      # Less restrict rules from user's project roles
      workflow_rules.each do |attr, rules|
        next if rules.size < roles.size # de todas as regras de um CF, retornará a mais restritiva

        uniq_rules = rules.values.uniq
        if uniq_rules.size == 1
          result[attr] = uniq_rules.first
        else
          result[attr] = 'required'
        end
      end
    end
    # adds all optional "CustomEntityCustomField"s. 
    field_ids = custom_field_ids.map(&:to_s)
    result.delete_if{|k,v| !field_ids.include?k}
    field_ids.delete_if{|k,v| result.include?k}
    field_ids.map{|f| result[f]=""}
    result
  end


  
  # Returns the names of required attributes for user or the current user
  # For users with multiple roles, the required fields are the intersection of
  # required fields of each role
  # The result is an array of strings where custom fields are represented with their ids
  def required_attribute_names(user=nil)
    # return [] if issue.nil? #TODO devo fazer isso? Esse método só invocado desta classe. Se não tiver projeto, invocar workflow_rule_by_attribute causará um erro.
    workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'required'}.keys
  end

  # Returns true if the attribute is required for user
  def required_attribute?(name, user=nil)
    return false if issue.nil? 
    required_attribute_names(user).include?(name.to_s)
  end

  def readonly_attribute_names(user=nil)
    return [] if issue.nil? 
    workflow_rule_by_attribute(user).select {|attr, rule| rule == 'readonly'}.keys
  end

  def readonly_attribute?(name, user=nil)
    return false if issue.nil?
    readonly_attribute_names(user).include?(name.to_s)
  end

end
