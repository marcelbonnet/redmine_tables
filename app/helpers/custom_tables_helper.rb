module CustomTablesHelper

  include WorkflowTable

  # usado em views/custom_tables/index.html.erb
  def render_custom_table_content(column, entity)
    value = column.value_object(entity)
    if value.is_a?(Array)
      value.collect {|v| send("#{entity.class.name.underscore}_column_value", column, entity, v)}.compact.join(', ').html_safe
    else
      if entity.is_a? CustomEntity
        custom_entity_column_value column, entity, value
      else
        custom_table_column_value column, entity, value
      end
    end
  end

  def custom_table_column_value(column, entity, value)
    case column.name
    when :name
      link_to value, custom_table_path(entity)
    when :visible
      is_true = (value.class.name == 'TrueClass')
      css = is_true ? "icon-only icon-visible-anonymous" : "icon-only icon-visible-roles"
      content_tag(:span, "", class: css)
    else
      format_object(value)
    end
  end

  def custom_entity_column_value(column, custom_entity, custom_value)
    return format_object(custom_value) unless custom_value.is_a? CustomValue
    value = custom_value.value
    case column.custom_field.field_format
    when 'belongs_to'
      if value.present? && custom_value.custom_entity_id
        link_to value, custom_entity_path(custom_value.custom_entity_id)
      else
        value || '---'
      end
    when 'bool'
      if custom_value.true?
        l(:general_text_Yes)
      else
        l(:general_text_No)
      end
    when 'date'
      if value.present?
        Date.parse(value).strftime(Setting.date_format)
      else
        '---'
      end
    else
      if custom_entity.main_custom_field.id == column.custom_field.id # If main custom value
        link_to value, custom_entity_path(custom_entity)
      else
        format_object(value)
      end
    end
  end



  # helper to change the behavior of an icon depending on issue status for an admin user
  def admin_icon(selector, entity)
    selector << "-admin" if User.current.admin? && entity.try(:issue).try(:closed?)
    selector
  end

  def admin_l(user_label, admin_label, entity)
    label = l(user_label)
    label = l(admin_label) if User.current.admin? && entity.try(:issue).try(:closed?)
    label
  end

  def allowed_column_content(column, entity)
    result = l(:missing_permission_view_table_rows_short_msg)
    ok = is_user_allowed_to_row?(:view_table_rows, entity)
    result = column_content(column, entity) if ok
    result
  end

  # def custom_tables_visible_options_for_select(selected)
  #   options_for_select([
  #     [l('custom_tables.label_visible'), '1'],
  #     [l('custom_tables.label_invisible'), '0'],
  #     ], selected ? '1' : '0' )
  # end

end
