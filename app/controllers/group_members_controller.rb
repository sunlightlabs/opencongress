class GroupMembersController < ApplicationController
  before_filter :login_required, :except => [ :index ]
  before_filter :find_by_group_id
  before_filter :disabled_groups_guard

  def find_by_group_id
    @group = Group.find(params[:group_id])
  end

  def disabled_groups_guard
    if @group.user.is_banned?
      flash[:notice] = "The #{@group.name} group has been disabled because it's creator was banned."
      redirect_to(:controller => 'groups', :action => 'index') and return
    end
  end

  def index
    @page_title = "Members of #{@group.name}"

    # if there's a status param, they probably got redirected here while trying to join
    # and not logged in, so run the create action
    unless params[:status].blank?
      create
      return
    end

    if @group.can_moderate?(current_user)
      @group_members = @group.group_members.includes(:user).order("users.login").paginate(:per_page => 100, :page => params[:page])
    else
      if @group.state or @group.district
        @group_members = @group.group_members.where("group_members.status != 'BOOTED' AND privacy_options.my_congressional_district=2").includes(:user => :privacy_option).order("UPPER(users.login)").paginate(:per_page => 100, :page => params[:page])
      else
        @group_members = @group.group_members.where("group_members.status != 'BOOTED'").includes(:user).order("UPPER(users.login)").paginate(:per_page => 100, :page => params[:page])
      end
    end
  end

  def update
    unless params[:status].blank?
      if (params[:status] == 'MODERATOR' and @group.is_owner?(current_user)) or
         (params[:status] != 'MODERATOR' and @group.can_moderate?(current_user))
        @group_member = GroupMember.find(params[:id])
        @group_member.status = params[:status]
        @group_member.save

        redirect_to group_group_members_path(@group), :notice => 'Membership has been updated.'
      else
        redirect_to @group, :error => 'You are not allowed to moderate this group!'
      end
    end

    unless params[:receive_owner_emails].blank?
      @group_member = GroupMember.find(params[:id])

      @group_member.receive_owner_emails = !@group_member.receive_owner_emails?
      @group_member.save

      render :text => @group_member.receive_owner_emails? ? 'On' : 'Off'
    end
  end

  def create
    # the only create action is to join a group (for now) so just set status if they can join
    if logged_in? and @group.can_join?(current_user)
      @group.group_members.create(:user_id => current_user.id, :status => 'MEMBER')

      redirect_to @group, :notice => "You have joined #{@group.name}!"
    else
      redirect_to groups_path, :notice => "You are not allowed to join that group!"
    end
  end

  def destroy
    membership = GroupMember.find(params[:id])

    if (membership.user == current_user && membership.status != 'BOOTED')
      membership.destroy

      redirect_back_by_referer_or_default groups_path, :notice => "You have left #{@group.name}"
    else
      redirect_back_by_referer_or_default groups_path, :error => "There was an error with your request."
    end
  end
end
