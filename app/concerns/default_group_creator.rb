module DefaultGroupCreator

  def self.included(includer)
    includer.class_eval do
      has_one :group
      after_create :create_default_group
    end
  end

  def create_default_group
    if group.nil?
      owner = User.find_by_login(Settings.default_group_owner_login)
      return if owner.nil?

      grp = Group.new(:user_id => owner.id,
                      :name => default_group_name,
                      :description => default_group_description,
                      :join_type => "INVITE_ONLY",
                      :invite_type => "MODERATOR",
                      :post_type => "ANYONE",
                      :publicly_visible => true,
                      :district_id => self.id
                     )
      grp.save!
    end
  end

end
