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

  # TODO limpeza: remover lambda se não for necessário
  # validate lambda {
  #   # custom_values()
  #   # if new_record? || custom_field_values_changed?
  #   #         custom_field_values.each(&:validate_value)
  #   #       end
  #   # errors.add(:base, 'Must be friends to leave a comment') 
  #   # required_attribute?
  #   errors.add(CustomEntityCustomField.last.name, 'teste de erro') 
  # }

  # TODO limpeza: remover
  # validates_each :first_name, :last_name do |record, attr, value|
  #   record.errors.add attr, 'starts with z.' if value.to_s[0] == ?z
  # end

  def name
    if new_record?
      custom_table.name
    else
      custom_value = custom_values.detect { |cv| cv.custom_field == custom_table.main_custom_field }
      custom_value.try(:value) || '---'
    end
  end

  # FIXME mover a função do helper para cá?
  def editable?(user = User.current)
    return true if user.admin? || custom_table.is_for_all
    user.allowed_to?(:edit_issues, issue.project)
  end

  def visible?(user = User.current)
    user.allowed_to?(:view_and_manage_entities, nil, global: true)
  end

  def deletable?(user = nil)
    editable?
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

  # TODO limpeza: remover método validate_unwriteable_fields se não for mesmo necessário
  # # Validates the fields against "readonly" workflow requirements.
  # def validate_unwriteable_fields
  #   # ignore if there is no project to get the user Roles
  #   return if self.try(:issue).try(:project).nil?

  #   user = new_record? ? author : current_journal.try(:user)
  #   readonly_attribute_names(user).each do |attribute|
  #     attribute = attribute.to_i
  #     v = custom_field_values.detect {|v| v.custom_field_id == attribute}
  #     if v && Array(v.value).detect(&:present?)
  #       # binding.pry
  #       # esses campos estão no params? talvez devam ser marcados como unsafe
  #       # eu preciso coibir o envio desses campos RO pelo params/robot, api...
  #       # mas a view também está disparando erro quando chega nesse método
  #       #   ver que params a view está mandando
  #       # o controlador não deve carregar o custom value que não pode ser editado, assim ele virá vazio. Qualquer valor aqui será persistido no save... Nem sei se o valor que está aqui veio do objeto ou do request?
  #       errors.add(v.custom_field.name, l('activerecord.errors.messages.readonly_cf'))
  #     end
  #   end
  # end

  # TODO limpeza: remover método validate_permissions se não for mesmo necessário
  # def validate_permissions
  #   binding.pry
  #   trackers = allowed_target_trackers(User.current)
  #   unless trackers.nil? 
  #     unless trackers.include?(self.try(:issue).try(:tracker))
  #       errors.add :tracker, :invalid
  #     end
  #   end
  # end

  # TODO limpeza: remover método
  # # Returns a scope of trackers that user can assign the issue to
  # def allowed_target_trackers(user=User.current)
  #   self.class.allowed_target_trackers(issue, user, issue.tracker_id_was) unless self.try(:issue).nil?
  # end

  # TODO limpeza: remover método
  # # Returns a scope of trackers that user can assign project issues to
  # def self.allowed_target_trackers(issue, user=User.current, current_tracker=nil)
  #   if issue.project
  #     scope = issue.project.trackers.sorted
  #     unless user.admin?
  #       roles = user.roles_for_project(issue.project).select {|r| r.has_permission?(:manage_custom_tables)}
  #       unless roles.any? {|r| r.permissions_all_trackers?(:manage_custom_tables)}
  #         tracker_ids = roles.map {|r| r.permissions_tracker_ids(:manage_custom_tables)}.flatten.uniq
  #         if current_tracker
  #           tracker_ids << current_tracker
  #         end
  #         scope = scope.where(:id => tracker_ids)
  #       end
  #     end
  #     scope
  #   else
  #     Tracker.none
  #   end
  # end

  

  # Returns a hash of the workflow rule by attribute for the given user
  #
  # Examples:
  #   custom_entity.workflow_rule_by_attribute # => {'due_date' => 'required', 'start_date' => 'readonly'}
  def workflow_rule_by_attribute(user=nil)
    return @workflow_rule_by_attribute if @workflow_rule_by_attribute && user.nil?
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
    @workflow_rule_by_attribute = result if user.nil?
    result
  end
  # private :workflow_rule_by_attribute

  # def attribute_names_by_workflow_rule(user=nil)
  #   workflow_rule_by_attribute(user).select {|attr, rule| rule != 'readonly'}.keys
  # end

  # Returns the names of required attributes for user or the current user
  # For users with multiple roles, the required fields are the intersection of
  # required fields of each role
  # The result is an array of strings where custom fields are represented with their ids
  def required_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'required'}.keys
  end

  # Returns true if the attribute is required for user
  def required_attribute?(name, user=nil)
    required_attribute_names(user).include?(name.to_s)
  end

  def readonly_attribute_names(user=nil)
    workflow_rule_by_attribute(user).select {|attr, rule| rule == 'readonly'}.keys
  end

  def readonly_attribute?(name, user=nil)
    readonly_attribute_names(user).include?(name.to_s)
  end

end
