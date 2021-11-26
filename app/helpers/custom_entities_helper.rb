module CustomEntitiesHelper

  include WorkflowTable

  # usado em views/custom_entities/_history.html.erb
  def render_custom_entity_notes(journal, options={})
    content = ''
    links = []
    content << content_tag('div', links.join(' ').html_safe, class: 'contextual') unless links.empty?
    content << textilizable(journal, :notes)
    css_classes = "wiki"
    css_classes << " editable"
    content_tag('div', content.html_safe, :id => "journal-#{journal.id}-notes", class: css_classes)
  end

  # usado em views/custom_tables/show.json.jbuilder e views/custom_tables/show.api.rsb
  def render_api_custom_entity(custom_entity, api)
    return if custom_entity.custom_values.empty?
    api.id custom_entity.id
    custom_entity.custom_field_values.each do |custom_field_value|
      custom_field = custom_field_value.custom_field
      external_name = custom_field.external_name
      value = custom_field_value.value
      next unless external_name.present?
      api.__send__(external_name, value)
    end
    api.issue_id custom_entity.issue_id
    api.custom_table_id custom_entity.custom_table_id
  end

  def entity_heading()
    if @custom_entity.issue.nil?
      field_id = @custom_entity.custom_table.settings["main_custom_field_id"].try(:to_i)
      value = ""
      unless field_id.nil?
        value << " - " << @custom_entity.custom_field_value(field_id)
      end
      return h("#{l(:label_entity_row)} ##{@custom_entity.id} #{value}")
    else
      return h("#{l(:label_entity_header)} #{@custom_entity.issue.tracker} ##{@custom_entity.issue.id}")
   end
  end
end
