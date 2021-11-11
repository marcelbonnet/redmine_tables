class TableMembershipsController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :find_membership, :only => [:edit]

  def edit
    @roles = Role.givable.to_a
    respond_to do |format|
      format.js
      format.html
    end
  end

  def find_membership
    begin
      @membership = TableMember.find(params[:id])
      @group = Group.find(params[:group_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end

end