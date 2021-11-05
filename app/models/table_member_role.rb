class TableMemberRole < ActiveRecord::Base
  belongs_to :table_member
  belongs_to :role

  after_destroy :remove_member_if_empty

  # after_create :add_role_to_group_users, :add_role_to_subprojects
  after_destroy :remove_inherited_roles

  validates_presence_of :role
  validate :validate_role_member

  def validate_role_member
    errors.add :role_id, :invalid if role && !role.member? # see Role.member?
  end

  def inherited?
    !inherited_from.nil?
  end

  # Returns the TableMemberRole from which self was inherited, or nil
  def inherited_from_member_role
    TableMemberRole.find_by_id(inherited_from) if inherited_from
  end

  # Destroys the TableMemberRole without destroying its TableMember if it doesn't have any other roles
  def destroy_without_member_removal
    @member_removal = false
    destroy
  end

  private

  def remove_member_if_empty
    if @member_removal != false && table_member.roles.empty?
      table_member.destroy
    end
  end

  def add_role_to_group_users
    if table_member.principal.is_a?(Group) && !inherited?
      table_member.principal.users.each do |user|
        user_member = TableMember.find_or_new(table_member.custom_table_id, user.id)
        user_member.table_member_roles << TableMemberRole.new(:role => role, :inherited_from => id)
        user_member.save!
      end
    end
  end

  # def add_role_to_subprojects
  #   member.project.children.each do |subproject|
  #     if subproject.inherit_members?
  #       child_member = Member.find_or_new(subproject.id, member.user_id)
  #       child_member.member_roles << MemberRole.new(:role => role, :inherited_from => id)
  #       child_member.save!
  #     end
  #   end
  # end

  def remove_inherited_roles
    TableMemberRole.where(:inherited_from => id).destroy_all
  end
end
