class TableFieldsController < CustomFieldsController
  layout 'admin'
  self.main_menu = false

  helper :custom_fields
  helper :custom_tables
  helper :queries
  include QueriesHelper

  before_action :authorize_global
  before_action :build_new_custom_field, only: [:new, :create]

  def new
    @custom_table = CustomTable.find(params[:custom_table_id])
    @tab = @custom_table.name
    super
  end

  def create
    update_tracker
    
    if @custom_field.save
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.html do
          redirect_back_or_default custom_table_path(id: @custom_field.custom_table)
        end
        format.js
      end
    else
      respond_to do |format|
        format.js { render action: 'new' }
        format.html { render action: 'new' }
      end
    end
  end

  def edit
    @tab = @custom_field.custom_table.name

    respond_to do |format|
      format.js
      format.html
    end
  end

  def update

    @custom_field.safe_attributes = params[:custom_field]
    
    update_tracker

    if @custom_field.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default custom_table_path(@custom_field.custom_table)
        }
        format.js { head 200 }
      end
    else
      respond_to do |format|
        format.html { render action: 'edit'}
        format.js { head 422 }
      end
    end
  end

  def destroy
    table = @custom_field.custom_table
    @custom_field.destroy

    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_successful_delete)
        redirect_back_or_default custom_table_path(id: table)
      }
      format.api { render_api_ok }
    end
  end

  private

  def build_new_custom_field
    @custom_field = CustomEntityCustomField.new
    @custom_field.safe_attributes = params[:custom_field]
  end

  def update_tracker
    # FIXME ver como fazer uma transaction aqui. No controler de workflows do redmine tem um de exemplo
    @custom_field.custom_table.trackers.each do |t|
      t.custom_entity_custom_fields << @custom_field
      begin
        t.validate!
      rescue => e
        respond_to do |format|
          format.html { render action: 'edit'}
          format.js { head 500 }
        end
      end
      t.save
    end
  end

end