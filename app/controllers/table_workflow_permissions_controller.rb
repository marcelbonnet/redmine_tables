class TableWorkflowPermissionsController < ApplicationController
  layout 'admin'
  self.main_menu = false

  include WorkflowsHelper
  
  # TODO accept_api_auth :permissions

  def permissions
    raise Unauthorized unless User.current.admin?

    find_trackers_roles_and_statuses_for_edit

    if request.post? && @roles && @trackers && params[:permissions]
      permissions = params[:permissions].deep_dup
      permissions.each do |field, rule_by_status_id|
        rule_by_status_id.reject! {|status_id, rule| rule == 'no_change'}
      end
      WorkflowPermission.replace_permissions(@trackers, @roles, permissions)
      flash[:notice] = l(:notice_successful_update)
      redirect_to_referer_or custom_tables_workflows_permissions_path
      return
    end

    if @roles && @trackers
      @custom_fields = @trackers.map(&:custom_entity_custom_fields).flatten.uniq.sort
      @permissions = WorkflowPermission.rules_by_status_id(@trackers, @roles)
      @statuses.each {|status| @permissions[status.id] ||= {}}
    end
  end

  def copy
    raise Unauthorized unless User.current.admin?
    
    @roles = Role.order(:name).select(&:consider_workflow?)
    @trackers = Tracker.order(:name)

    if params[:source_tracker_id].blank? || params[:source_tracker_id] == 'any'
      @source_tracker = nil
    else
      @source_tracker = Tracker.find_by_id(params[:source_tracker_id].to_i)
    end
    if params[:source_role_id].blank? || params[:source_role_id] == 'any'
      @source_role = nil
    else
      @source_role = Role.find_by_id(params[:source_role_id].to_i)
    end
    @target_trackers =
      if params[:target_tracker_ids].blank?
        nil
      else
        Tracker.where(:id => params[:target_tracker_ids]).to_a
      end
    @target_roles =
      if params[:target_role_ids].blank?
        nil
      else
        Role.where(:id => params[:target_role_ids]).to_a
      end
    if request.post?
      if params[:source_tracker_id].blank? || params[:source_role_id].blank? ||
           (@source_tracker.nil? && @source_role.nil?)
        flash.now[:error] = l(:error_workflow_copy_source)
      elsif @target_trackers.blank? || @target_roles.blank?
        flash.now[:error] = l(:error_workflow_copy_target)
      else
        WorkflowRule.copy(@source_tracker, @source_role, @target_trackers, @target_roles)
        flash[:notice] = l(:notice_successful_update)
        redirect_to(
          custom_tables_workflows_permissions_copy_path(:source_tracker_id => @source_tracker,
                              :source_role_id => @source_role)
        )
      end
    end
  end

  def teste
  end

  private

  # loads the needed class attributes to populate the view
  def find_trackers_roles_and_statuses_for_edit
    find_roles
    find_trackers
    find_statuses
  end

  def find_roles
    ids = Array.wrap(params[:role_id])
    if ids == ['all']
      @roles = Role.order(:name).select(&:consider_workflow?) # can add/edit issue
    elsif ids.present?
      @roles = Role.where(:id => ids).order(:name).to_a
    end
    @roles = nil if @roles.blank?
  end

  def find_trackers
    ids = Array.wrap(params[:tracker_id])
    if ids == ['all']
      @trackers = Tracker.order(:name).to_a
    elsif ids.present?
      @trackers = Tracker.where(:id => ids).order(:name).to_a
    end
    @trackers = nil if @trackers.blank?
  end

  def find_statuses
    @used_statuses_only = (params[:used_statuses_only] == '0' ? false : true)
    if @trackers && @used_statuses_only
      role_ids = Role.all.select(&:consider_workflow?).map(&:id)
      status_ids = WorkflowTransition.where(
        :tracker_id => @trackers.map(&:id), :role_id => role_ids
      ).distinct.pluck(:old_status_id, :new_status_id).flatten.uniq
      @statuses = IssueStatus.where(:id => status_ids).sorted.to_a.presence
    end
    @statuses ||= IssueStatus.sorted.to_a
  end

end
