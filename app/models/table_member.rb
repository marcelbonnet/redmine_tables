class TableMember < ActiveRecord::Base
	belongs_to :user
  belongs_to :principal, :foreign_key => 'user_id'
  has_many :table_member_roles, :dependent => :destroy
  has_many :roles, lambda {distinct}, :through => :table_member_roles
  belongs_to :custom_table

  validates_presence_of :principal, :custom_table
  validates_uniqueness_of :user_id, :scope => :custom_table
  validate :validate_role

  # before_destroy :set_issue_category_nil, :remove_from_project_default_assigned_to

  # scope :active, (lambda do
  #   joins(:principal).where(:users => {:status => Principal::STATUS_ACTIVE})
  # end)
  # # Sort by first role and principal
  # scope :sorted, (lambda do
  #   includes(:member_roles, :roles, :principal).
  #     reorder("#{Role.table_name}.position").
  #     order(Principal.fields_for_order_statement)
  # end)
  # scope :sorted_by_project, (lambda do
  #   includes(:project).
  #     reorder("#{Project.table_name}.lft")
  # end)

  # alias :base_reload :reload
  # def reload(*args)
  #   @managed_roles = nil # precisa de patch em Role se for usar: ver has_and_belongs_to_many :managed_roles, ...
  #   base_reload(*args)
  # end

  def role
  end

  def role=
  end

  def name
    self.user.name
  end

  alias :base_role_ids= :role_ids=
  def role_ids=(arg)
    ids = (arg || []).collect(&:to_i) - [0]
    # Keep inherited roles
    ids += table_member_roles.select {|mr| !mr.inherited_from.nil?}.collect(&:role_id)

    new_role_ids = ids - role_ids
    # Add new roles
    new_role_ids.each do |id|
      table_member_roles << TableMemberRole.new(:role_id => id, :table_member => self)
    end
    # Remove roles (Rails' #role_ids= will not trigger MemberRole#on_destroy)
    table_member_roles_to_destroy = table_member_roles.select {|mr| !ids.include?(mr.role_id)}
    if table_member_roles_to_destroy.any?
      table_member_roles_to_destroy.each(&:destroy)
    end
  end

  def <=>(table_member)
    a, b = roles.sort, table_member.roles.sort
    if a == b
      if principal
        principal <=> table_member.principal
      else
        1
      end
    elsif a.any?
      b.any? ? a <=> b : -1
    else
      1
    end
  end

  # Set member role ids ignoring any change to roles that
  # user is not allowed to manage
  # def set_editable_role_ids(ids, user=User.current)
  #   ids = (ids || []).collect(&:to_i) - [0]
  #   editable_role_ids = user.managed_roles(project).map(&:id)
  #   untouched_role_ids = self.role_ids - editable_role_ids
  #   touched_role_ids = ids & editable_role_ids
  #   self.role_ids = untouched_role_ids + touched_role_ids
  # end

  # Returns true if one of the member roles is inherited
  def any_inherited_role?
    member_roles.any? {|mr| mr.inherited_from}
  end

  # Returns true if the member has the role and if it's inherited
  def has_inherited_role?(role)
    member_roles.any? {|mr| mr.role_id == role.id && mr.inherited_from.present?}
  end

  # Returns an Array of Table and/or Group from which the given role
  # was inherited, or an empty Array if the role was not inherited
  def role_inheritance(role)
    member_roles.
      select {|mr| mr.role_id == role.id && mr.inherited_from.present?}.
      map {|mr| mr.inherited_from_member_role.try(:table_member)}.
      compact.
      map {|m| m.custom_table == custom_table ? m.principal : m.custom_table}
  end

  # Returns true if the member's role is editable by user
  # def role_editable?(role, user=User.current)
  #   if has_inherited_role?(role)
  #     false
  #   else
  #     user.managed_roles(project).include?(role)
  #   end
  # end

  # Returns true if the member is deletable by user
  # def deletable?(user=User.current)
  #   if any_inherited_role?
  #     false
  #   else
  #     roles & user.managed_roles(project) == roles
  #   end
  # end

  # Destroys the member
  def destroy
  	# FIXME testar isso
    table_member_roles.reload.each(&:destroy_without_member_removal)
    super
  end

  # Returns true if the member is user or is a group
  # that includes user
  def include?(user)
    if principal.is_a?(Group)
      !user.nil? && user.groups.include?(principal)
    else
      self.principal == user
    end
  end

  # Returns the roles that the member is allowed to manage
  # in the project the member belongs to
  # FIXME: se for usar preciso implementar "has_and_belongs_to_many :managed_roles,..." no patch de Role para isso.
  # def managed_roles
  #   @managed_roles ||= begin
  #     if principal.try(:admin?)
  #       Role.givable.to_a
  #     else
  #       members_management_roles = roles.select do |role|
  #         role.has_permission?(:manage_members)
  #       end
  #       if members_management_roles.empty?
  #         []
  #       elsif members_management_roles.any?(&:all_roles_managed?)
  #         Role.givable.to_a
  #       else
  #         members_management_roles.map(&:managed_roles).reduce(&:|)
  #       end
  #     end
  #   end
  # end

  # Creates memberships for principal with the attributes, or add the roles
  # if the membership already exists.
  # * table_ids : one or more table ids
  # * role_ids : ids of the roles to give to each membership
  #
  # Example:
  #   TableMember.create_principal_memberships(user, :table_ids => [2, 5], :role_ids => [1, 3]
  def self.create_table_memberships(principal, attributes)
    table_members = []
    if attributes
      table_ids = Array.wrap(attributes[:table_ids] || attributes[:table_id])
      role_ids = Array.wrap(attributes[:role_ids])
      table_ids.each do |table_id|
        table_member = TableMember.find_or_new(table_id, principal)
        table_member.role_ids |= role_ids
        table_member.save
        table_members << table_member
      end
    end
    table_members
  end

  # Finds or initializes a TableMember for the given table and principal
  def self.find_or_new(table, principal)
    custom_table_id = table.is_a?(CustomTable) ? table.id : table
    principal_id = principal.is_a?(Principal) ? principal.id : principal

    table_member = TableMember.find_by(custom_table_id: custom_table_id, user_id: principal_id)
    table_member ||= TableMember.new(:custom_table_id => custom_table_id, :user_id => principal_id)
    table_member
  end

  protected

  def validate_role
    errors.add(:role, :empty) if table_member_roles.empty? && roles.empty?
  end

end