class CustomEntitiesController < ApplicationController
  layout 'admin'
  self.main_menu = false

  helper :issues
  include TimelogHelper
  helper :journals
  include WorkflowTable
  helper :context_menus
  helper :custom_fields
  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper
  helper :custom_tables_pdf

  helper :attachments
  include AttachmentsHelper

  accept_api_auth :show, :create, :update, :destroy

  before_action :authorize_global
  before_action :find_custom_entity, only: [:show, :edit, :update, :add_belongs_to, :new_note]
  before_action :find_custom_entities, only: [:context_menu, :bulk_edit, :bulk_update, :destroy, :context_export]
  before_action :find_journals, only: :show

  # FIXME implementar algo ? o index HTML é uma tela vazia. API ?
  def index
    respond_to do |format|
      format.html
      format.api
    end
  end

  def show
    raise Unauthorized unless is_user_allowed_to_row?(:view_table_rows, @custom_entity)

    @queries_scope = []
    respond_to do |format|
      format.js
      format.html
      format.api
      format.pdf  { send_file_headers! type: 'application/pdf', filename: "#{@custom_entity.name}.pdf" }
    end
  end

  def new
    params.permit(["custom_table_id","issue_id","controller","action","back_url"])
    @custom_entity = CustomEntity.new
    @custom_entity.custom_table_id = params[:custom_table_id]
    @custom_entity.custom_field_values = params[:custom_entity][:custom_field_values] if params[:custom_entity]
    @custom_entity.issue_id = params[:issue_id] #|| params[:custom_entity][:issue_id]

    raise Unauthorized unless is_user_allowed_to_row?(:add_table_row, @custom_entity)

    respond_to do |format|
      format.js
      format.html
    end
  end

  def new_note
    #FIXME adicionar permissão

    respond_to do |format|
      format.js
      format.html
    end
  end

  def create
    params.permit(["custom_entity","issue_id","controller","action","back_url"])
    raise Unauthorized unless params.require("custom_entity")

    @custom_entity = CustomEntity.new(author: User.current, custom_table_id: params[:custom_entity][:custom_table_id], issue_id: params[:custom_entity][:issue_id])
    @custom_entity.safe_attributes = parametrize_allowed_attributes
    # @custom_entity.issue_id = params[:issue_id] || params[:custom_entity][:issue_id]

    raise Unauthorized unless is_user_allowed_to_row?(:add_table_row, @custom_entity)

    if @custom_entity.save
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.html { redirect_back_or_default custom_table_path(@custom_entity.custom_table) }
        format.js
        format.api  { render action: 'show', status: :created, location: custom_entity_url(@custom_entity) }
      end
    else
      respond_to do |format|
        format.js { render action: 'new' }
        format.html { render action: 'new' }
        format.api  { render_validation_errors(@custom_entity) }
      end
    end
  end

  # TODO test with API
  # FIXME CSV should consider setting's locale (decimal, date...): try lib/redmine/export/csv.rb: include Redmine::I18n ; @decimal_separator ||= l(:general_csv_decimal_separator)              ("%.2f" % field).gsub('.', @decimal_separator)
  def upload
    raise Unauthorized unless is_user_allowed_to_table?(:upload_csv_to_table, table: params[:custom_table_id])

    base_ce = CustomEntity.new(author: User.current, custom_table_id: params[:custom_table_id], issue_id: params[:custom_entity][:issue_id])
    # TODO: attach to issue, process and delete (or delete if true in plugin settings)
    # attachment = Attachment.attach_files(Issue.find(params[:custom_entity][:issue_id]), params[:attachments])

    begin
      attachment = Attachment.find(params[:attachments]["1"]["token"].split('.').first)
      # forçando na marra. Alguém deveria acts_as_attachable tabela ou entity. Mas para a entity, teria que salvar uma antes?
      # CustomTable.last.attachments (funcionou)
      attachment.container_id = params[:custom_table_id]
      attachment.container_type = "CustomTable"
      attachment.description = params[:attachments]["1"]["description"]
      attachment.save
    rescue => e
      flash[:error] = e.message
      @custom_entity = base_ce
      return respond_to do |format|
        format.js   { render action: 'new' }
        format.html { render action: 'new' }
        format.api  { render action: 'new' }
      end
    end


    path = Setting.find_by(name: "attachments_storage_path")
    path = "files" if path.nil?

    # FIXME: "/" if Unix
    # FIXME CSV has option for decimal separator?
    begin
      csv = CSV.open("#{path}/#{attachment.disk_directory}/#{attachment.disk_filename}", headers: true, header_converters: :symbol, col_sep: ';', encoding: "UTF-8").map(&:to_h)
    rescue
      csv = CSV.open("#{path}/#{attachment.disk_directory}/#{attachment.disk_filename}", headers: true, header_converters: :symbol, col_sep: ';', encoding: "ISO8859-1").map(&:to_h)
    end
    
    @custom_entities = []


    csv.each{|row|
      ce = base_ce.dup
      safe_attributes = ce.custom_field_values.collect{|o| o.custom_field_id} - ce.readonly_attribute_names.map(&:to_i)
      if safe_attributes.size == 0
        @ro_attrs_err = l("activerecord.errors.messages.readonly_fields")
        next
      end
      ce.custom_table.custom_fields.map{|cf| [cf.id, cf.external_name.downcase.to_sym]}.each{|cf|
        ce.custom_field_values = {cf[0] => row[cf[1]]} if safe_attributes.include?(cf[0])
      }

      @custom_entities << ce
    }

    # no need to keep the file after loading its records. We can stil export the table to CSV.
    attachment.destroy

    @csv_is_valid = @custom_entities.collect{|ce| ce.valid? }.inject{|memo, v| memo&=v}

    if @csv_is_valid
      @custom_entities.each{|ce| ce.save }
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        # enquanto tiver uma tela administrativa de tabela:
        # precisa retornar para a página de onde viemos: issue_path ou custom_table_path
        # format.html { redirect_back_or_default custom_table_path(@custom_entities.last.custom_table) }
        format.html { redirect_back_or_default issue_path(@custom_entities.last.issue_id) }
        format.js
        format.api  { render action: 'show', status: :created, location: custom_entity_url(@custom_entities.last) }
      end
    else
      flash[:error] = @ro_attrs_err if @ro_attrs_err
      respond_to do |format|
        format.js { render action: 'new' }
        format.html { render action: 'new' }
        format.api  { render_validation_errors([@custom_entities, @csv_is_valid]) }
      end
    end

  end #upload

  def edit
    raise Unauthorized unless is_user_allowed_to_row?(:edit_table_row, @custom_entity)

    @tab = @custom_entity.custom_table.name
    respond_to do |format|
      format.js
      format.html
    end
  end

  def update
    raise Unauthorized unless is_user_allowed_to_row?(:edit_table_row, @custom_entity)

    @custom_entity.init_journal(User.current)
    @custom_entity.safe_attributes = parametrize_allowed_attributes

    if @custom_entity.save
      flash[:notice] = l(:notice_successful_update)
      respond_to do |format|
        format.html { redirect_back_or_default custom_table_path(@custom_entity.custom_table) }
        format.js
        format.api  { render action: 'show', status: :created, location: custom_entity_url(@custom_entity) }
      end
    else
      respond_to do |format|
        format.js { render action: 'edit' }
        format.html { render action: 'edit' }
        format.api  { render_validation_errors(@custom_entity) }
      end
    end
  end

  def destroy
    @custom_entities.each do |ce|
      raise Unauthorized unless is_user_allowed_to_row?(:delete_table_row, ce)
    end

    custom_table = @custom_entities.first.custom_table
    @custom_entities.destroy_all

    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_successful_delete)
        redirect_back_or_default custom_table_path(custom_table)
      }
      format.api { render_api_ok }
    end
  end

  #FIXME onde é usado? precisa de permissão?
  def add_belongs_to
    @custom_field = CustomEntityCustomField.find(params[:custom_field_id])
    @tab = @custom_entity.custom_table.name
    respond_to do |format|
      format.js
      format.html
    end
  end

  def context_menu
    if (@custom_entities.size == 1)
      @custom_entity = @custom_entities.first
    end
    @custom_entity_ids = @custom_entities.map(&:id).sort

    can_edit = @custom_entities.detect{|c| !c.editable?}.nil?
    can_delete = @custom_entities.detect{|c| !c.deletable?}.nil?
    @can = {:edit => can_edit, :delete => can_delete}
    @back = back_url

    @safe_attributes = @custom_entities.map(&:safe_attribute_names).reduce(:&)

    render :layout => false
  end

  def bulk_edit
    @custom_entities.each do |ce|
      raise Unauthorized unless is_user_allowed_to_row?(:table_bulk_edit, ce)
    end

    @custom_fields = @custom_entities.map { |c| c.available_custom_fields }.reduce(:&).uniq
  end

  def bulk_update
    @custom_entities.each do |ce|
      raise Unauthorized unless is_user_allowed_to_row?(:table_bulk_edit, ce)
    end
    
    unsaved, saved = [], []
    action_parameters = parse_params_for_bulk_update(params[:custom_entity])
    
    @custom_entities.each do |custom_entity|
      custom_entity.init_journal(User.current)
      custom_entity.safe_attributes = action_parameters.dup.permit("custom_field_values": (custom_entity.custom_field_values.collect{|o| o.custom_field_id} - custom_entity.readonly_attribute_names.map(&:to_i)).map(&:to_s))
      if custom_entity.save
        saved << custom_entity
      else
        unsaved << custom_entity
      end
    end
    respond_to do |format|
      format.html do
        if unsaved.blank?
          flash[:notice] = l(:notice_successful_update)
        else
          flash[:error] = unsaved.map { |i| i.errors.full_messages }.flatten.uniq.join(",\n")
        end
        redirect_back_or_default custom_table_path(@custom_entities.first.custom_table)
      end
    end
  end

  def model
    CustomEntity
  end

  def context_export
    custom_table = @custom_entities.first.custom_table
    respond_to do |format|
      call_hook(:controller_custom_entities_context_export_format, { custom_entities: @custom_entities, custom_table: custom_table, format: format })
    end
  end

  private

  def find_journals
    @journals = @custom_entity.journals.preload(:journalized, :user, :details).reorder("#{Journal.table_name}.id ASC").to_a
    @journals.each_with_index { |j, i| j.indice = i+1 }
    Journal.preload_journals_details_custom_fields(@journals)
    @journals.reverse!
  end

  def find_custom_entity
    @custom_entity = CustomEntity.find(params[:id])
    render_403 unless @custom_entity.editable?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_custom_entities
    @custom_entities = CustomEntity.where(id: (params[:id] || params[:ids]))
  end

  def parametrize_allowed_attributes
    safe_attributes = params[:custom_entity]["custom_field_values"].to_unsafe_h.keys - @custom_entity.readonly_attribute_names
    params.require(:custom_entity).permit("custom_field_values": safe_attributes)
  end

end
