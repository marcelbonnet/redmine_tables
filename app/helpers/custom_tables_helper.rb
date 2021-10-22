module CustomTablesHelper

  # FIXME não é usado
  def render_setting_tabs(tabs, selected=params[:tab], locals = {})
    if tabs.any?
      unless tabs.detect {|tab| tab[:name] == selected}
        selected = nil
      end
      selected ||= tabs.first[:name]
      render :partial => 'common/tabs', :locals => {:tabs => tabs, :selected_tab => selected}.merge(locals)
    else
      content_tag 'p', l(:label_no_data), :class => "nodata"
    end
  end

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

  # FIXME não é usado
  def custom_table_column_value(column, entity, value)
    case column.name
    when :name
      link_to value, custom_table_path(entity)
    else
      format_object(value)
    end
  end

  # FIXME não é usado
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

  # * permissions: one symbol or an array of symbols
  def is_user_allowed_to_table?(permissions)
    user=User.current
    permissions = [permissions] unless permissions.is_a?(Array)
    permissions.collect{|perm|  
      if try(:issue).try(:project).nil?
        # FIXME se tabela não tiver projeto: 
        # => qualquer role do usuário já serve
        # => adicionar opção de role(s) para tabela que não tenha projeto
        user.allowed_to?(perm, nil, global: true)
      else
        user.allowed_to?(perm, issue.project)
      end
    }.inject{|memo,b| memo|=b }
  end

  # return true if usuário tem algum CF editável no status atual de uma issue
  def is_editable_to?
    user=User.current
    # true se não tiver projeto. Se tiver, poderá ou não ser adiciona por uma issue!
    
    # se tiver issue ...
      # return false if todos cfs readonly
      # return true
    
    # se não tiver issue ... (tem projeto, mas está sendo editada em outra view, sem issue)
      # return true if se usuário está no grupo autorizado para editar por fora
      # return false

  end

end
