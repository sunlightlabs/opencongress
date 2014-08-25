module ProfileHelper

  def avatar_for(user, options = {:size => :main, :alt => "Photo of"})
    if user.send("#{options[:size]}_picture".to_sym)
      pic = user.picture_path(options[:size])
    else
      pic = "anon-img-ex1.gif"
    end
    image_tag(pic, :alt => options[:alt])
  end

  def draw_edit_in_place(field, rows = 1)
      @user == current_user ? editable_content(
         :content => {
           :element => 'span',
           :text => (@user[field] && !@user[field].strip.empty?) ? h(@user[field]) : "[Click to Edit]",
           :options => {
             :id => "user_#{field}",
             :class => 'editable-content'
           }
          },
         :url => {
           :controller => 'profile',
           :action => 'edit_profile',
           :field => field,
           :login => @user.login
          },
         :ajax => {
           :okText => "'SAVE'",
           :highlightcolor => "'#DDDDDD'",
           :highlightendcolor => "'#FFFFFF'",
           :rows => rows,
           :cancelText => "'CANCEL'"
          }
       ) : @user[field] ? h(@user[field]) : "[Click to Edit]"
  end

  def editable_content(options)
    options[:content] = { :element => 'span' }.merge(options[:content])
    options[:url] = {}.merge(options[:url])
    options[:ajax] = { :okText => "'Save'", :cancelText => "'Cancel'"}.merge(options[:ajax] || {})
    script = Array.new
    script << "new Ajax.InPlaceEditor("
    script << "  '#{options[:content][:options][:id]}',"
    script << "  '#{url_for(options[:url])}',"
    script << "  {"
    script << options[:ajax].map{ |key, value| "#{key.to_s}: #{value}" }.join(", ")
    script << "  }"
    script << ")"

    content_tag(
      options[:content][:element],
      options[:content][:text],
      options[:content][:options]
    ) + javascript_tag( script.join("\n") )
  end

  def user_bill_vote_string(bill)
    out = "<td"
    if logged_in?
      bv = current_user.bill_votes.find_by_bill_id(bill.id)
      if bv
        if bv.support == 0
        out += " class='color10'>Aye"
        elsif bv.support == 1
        out += " class='color0'>Nay"
        end
      else
        out += ">No Vote"
      end
    end
    out += "\n</td>"
    return out.html_safe
  end

  def link_to_report(report)
    link_to report.title.capitalize, :action => :report, :id => report
  end

  def private_img
    image_tag("private.png", :alt => "private", :title => "Private")
  end

  # Takes an object or a valid type and a user via options hash,
  # returns the appropriate rating for the passed-in object's type, if available
  def rating_for(object, options = {})
    u = options[:rater]
    score = nil
    if object.is_a? Person
      score = u.person_approvals.where(:id => object.id).first.rating rescue nil
    elsif object.is_a? Bill
      vote = u.bill_votes.where(:id => object.id).first
      if vote
        score = vote.support ? "<div class='nay'></div>" : "<div class='aye'></div>"
      end
    end
    if !score
      "&mdash;".html_safe
    end
  end

  # Takes a symbol privacy attribute and, at a minimum, subject via options hash,
  # and returns the queried attribute, or a default or not-allowed value
  def privileged(attribute, options = {})
    options = {
      :not_allowed => private_img,
      :observer => current_user,
      :default => "&mdash;".html_safe
    }.merge options
    user = options[:subject]
    obs = options[:observer]
    default = options[:default]
    na = options[:not_allowed]
    perm = options[:permission]
    if user.can_view(perm, obs)
      val = user.send(attribute)
      return val unless val.nil?
      return default
    end
    na
  end

  def profile_image_for(user=nil, options={})
    user ||= current_user
    size = profile_image_size(options[:size]) || profile_image_size(:default)
    editable = options[:editable].nil? ? (user == current_user) : options[:editable]
    render :partial => "profile/profile_image", :locals => {:user => user, :size => size, :editable => editable }
  end

  def profile_image_size(forced_value=nil)
    options = [:main_picture, :small_picture]
    if forced_value.present?
      return options.include?(forced_value.to_sym) ? forced_value.to_sym : options[0]
    end
    options[0]
  end

  def profile_facebook_for(user=nil, options={})
    user ||= current_user
    editable = options[:editable].nil? ? (user == current_user) : options[:editable]
    render :partial => 'profile/profile_facebook_connect', :locals => {:user => user, :editable => editable}
  end

  def show_vote(user,bill)
    vote = user.bill_votes.find_by_bill_id(bill.id)
    if vote.nil?
      "None"
    elsif vote.support == 0
      "Aye"
    elsif vote.support == 1
      "Nay"
    else
      "None"
    end
  end

  def show_person_vote(person,bill)
    out = ''
    roll_calls = RollCall.where(bill_id:bill.id)
    unless roll_calls.empty?
      rc_votes = RollCallVote.eager_load(:roll_call).where(roll_call_id:roll_calls,person_id:person).order('roll_calls.date DESC').limit(1)
      logger.info rc_votes.to_yaml
      unless rc_votes.empty?
        out_ar = []
        rc_votes.each do |rcv|
          out_ar << (rcv.vote == "+" ? "Aye" : ( rcv.vote == "-" ? "Nay" : "Abstain" )) + ' : <span style="font-size:10px;font-style:italics;">' + rcv.roll_call.roll_type + '</span>'
        end
        out << out_ar.join('<br/>')
      end
    end
    if out == ""
      if vote_origin = bill.originating_chamber_vote
        if (vote_origin.where == "h" && person.title == "Rep.") || (vote_origin.where == "s" && person.title == "Sen.")
          if vote_origin.how == "by Unanimous Consent"
            out << (vote_origin.result == "pass" ? "Aye" : "Nay")
            out << '<span style="font-size:10px;font-style:italics;"> (unanimous)</span>'
          end
        end
      end
      if vote_other = bill.other_chamber_vote
        if (vote_other.where == "h" && person.title == "Rep.") || (vote_other.where == "s" && person.title == "Sen.")
          if vote_other.how == "by Unanimous Consent"
            out << (vote_other.result == "pass" ? "Aye" : "Nay")
            out << '<span style="font-size:10px;font-style:italics;"> (unanimous)</span>'
          end
        end
      end
      if out == ""
        out << "None"
      end
    end
    return out.html_safe
  end

end
