module GroupsHelper
  def group_image(group)
    group.group_image_file_name.blank? ? image_tag('promo.gif') : image_tag(group.group_image.url(:thumb))
  end
  
  def group_header_class(sort_target, sort_type)
    if sort_type =~ /^#{sort_target}/i
      return (sort_type =~ /desc/i) ? 'down' : 'up'
    end
    
    return ''
  end
  
  def group_members_num(group)
    !group.has_attribute?(:group_members_count) ? group.active_members.count + 1 : group.group_members_count.to_i + 1
  end

  def group_members_num_with_delimiter(group)
    number_with_delimiter(group_members_num(group))
  end
  
  def show_search?
    @state.nil?
  end

  def grouped_subject_options (selected, prompt)
    # TODO: This will need to change with Rails 4.0
    groups = {}
    root_subject_id = Subject.root_category.id
    Subject.where('parent_id IS NOT NULL').each do |sub|
      if sub.parent_id == root_subject_id
        groups[sub.term] = [[sub.term, sub.id]]
      else
        (groups[sub.parent.term] ||= []).push([sub.term, sub.id])
      end
    end

    grouped_options_for_select(groups.to_a, selected, prompt)
  end
end

