class CustomTable < ActiveRecord::Base
  include Redmine::SafeAttributes

  # CustomTable statuses
  STATUS_ACTIVE     = 1
  STATUS_CLOSED     = 5
  STATUS_ARCHIVED   = 9

  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  has_many :custom_fields, dependent: :destroy
  has_many :custom_entities, dependent: :destroy
  has_one :custom_entity
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :trackers
  has_and_belongs_to_many :roles

  acts_as_nested_set
  acts_as_attachable

  store :settings, accessors: [:main_custom_field_id], coder: JSON

  scope :sorted, lambda { order("#{table_name}.name ASC") }

  scope :like, lambda {|arg|
    if arg.present?
      pattern = "%#{arg.to_s.strip}%"
      where("LOWER(name) LIKE LOWER(:p)", p: pattern)
    end
  }

  scope :active, lambda { where(:status => STATUS_ACTIVE) }
  scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i})}
  # TODO public table, allowing public view + add|edit|remove ?

  # The table is visible if:
  #  - Has attribute/column visible=true
  #  - User belongs to a Group that has TableMembership (when Table is not related to a Project)
  #  - User belongs to a Project related to the Table
  scope :visible, lambda {|*args|
    user = args.shift || User.current
    if !user.admin?
      user_table_ids = user.groups.map{|g| g.table_memberships.map(&:custom_table_id) }.flatten

      user_projects_table_ids = user.projects.map(&:custom_table_ids).flatten.uniq

      where("#{table_name}.visible = ? or #{table_name}.id in (?) or #{table_name}.id in (?)", true, user_table_ids, user_projects_table_ids)
    end
  }

  safe_attributes 'name', 'author_id', 'main_custom_field_id', 'project_ids', 'is_for_all', 'description', 'tracker_ids', 'role_ids', 'visible', 'max_rows', 'pivot'

  validates :name, presence: true, uniqueness: true

  acts_as_customizable

  def css_classes
    s = 'project'
    s << ' root' if root?
    s << ' child' if child?
    s << (leaf? ? ' leaf' : ' parent')
    s
  end

  def main_custom_field
    CustomField.find_by(id: main_custom_field_id) || custom_fields.first
  end

  def query(totalable_all: false)
    query = CustomEntityQuery.new(name: '_', custom_table_id: id)
    visible_cfs = custom_fields.visible.sorted
    query.column_names ||= visible_cfs.map {|i| "cf_#{i.id}"}
    if totalable_all
      query.totalable_names = visible_cfs.select(&:totalable?).map {|i| "cf_#{i.id}"}
    end
    query
  end

end
