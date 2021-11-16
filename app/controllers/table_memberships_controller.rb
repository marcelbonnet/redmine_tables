class TableMembershipsController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin
  before_action :find_group, :only => [:new, :create]
  before_action :find_membership, :only => [:edit, :update, :destroy]

  def new
    @tables = CustomTable.active.all
    @roles = Role.find_all_givable
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    params.require(:membership)
    @members = TableMember.create_table_memberships(@group, params[:membership])
    respond_to do |format|
      format.html {redirect_to_tab @group}
      format.js
    end
  end

  def edit
    @roles = Role.givable.to_a
    respond_to do |format|
      format.js
      format.html
    end
  end

  def update
    @membership.attributes = params.require(:membership).permit(:role_ids => [])
    @membership.save
    respond_to do |format|
      format.html {redirect_to_tab @group}
      format.js
    end
  end

  def destroy
    # if @membership.deletable?
      @membership.destroy
    # end
    respond_to do |format|
      format.html {redirect_to_tab @group}
      format.js
    end
  end


  private

  def find_membership
    begin
      @membership = TableMember.find(params[:id])
      @group = Group.find(params[:group_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end

  def find_group
    @group = Group.find(params[:group_id])
    rescue ActiveRecord::RecordNotFound
      render_404
  end

  def redirect_to_tab(group)
    redirect_to edit_polymorphic_path(group, :tab => 'table_memberships')
  end

end