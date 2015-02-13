require 'spec_helper'

describe ProfileController, type: :controller do
  before :each do
    VCR.use_cassette("create_user") do
      @current_user = FactoryGirl.create(:user)
    end
    @session = { :user => @current_user.id }

    request.env['HTTP_REFERER'] = '/'
  end

  describe 'upload_pic' do
    it 'uploads an avatar in 2 sizes' do
      post(:upload_pic,
           { :picture => {'tmp_file' => fixture_file_upload('/files/avatar.jpg', 'image/jpeg')}},
           @session
      )
      @current_user.reload
      expect(@current_user.main_picture).to eq("#{@current_user.login}_m.jpg")
      expect(@current_user.small_picture).to eq("#{@current_user.login}_s.jpg")
    end
  end

  describe 'delete_images' do
    it 'deletes both avatars' do
      post(:upload_pic,
           { :picture => {'tmp_file' => fixture_file_upload('/files/avatar.jpg', 'image/jpeg')}},
           @session
      )
      @current_user.reload
      expect(@current_user.main_picture).to eq("#{@current_user.login}_m.jpg")
      expect(@current_user.small_picture).to eq("#{@current_user.login}_s.jpg")

      post(:delete_images, {}, @session)
      user = User.find(@current_user.id)
      expect(user.user_profile.main_picture).to be_nil
      expect(user.user_profile.small_picture).to be_nil
    end
  end
end
