require 'spec_helper'

describe ProfileController, type: :controller do
  # fixtures :users
  let(:current_user) { User.find_by_login('dan') }
  let(:session) do
    { :user => current_user.id }
  end

  before :each do
    request.env['HTTP_REFERER'] = '/'
  end

  describe 'upload_pic' do
    it 'uploads an avatar in 2 sizes' do
      post(:upload_pic,
           { :picture => {'tmp_file' => fixture_file_upload('/files/avatar.jpg', 'image/jpeg')}},
           session
      )
      user = User.find(current_user.id)
      expect(user.main_picture).to eq('dan_m.jpg')
      expect(user.small_picture).to eq('dan_s.jpg')
    end
  end

  describe 'delete_images' do
    it 'deletes both avatars' do
      post(:upload_pic,
           { :picture => {'tmp_file' => fixture_file_upload('/files/avatar.jpg', 'image/jpeg')}},
           session
      )
      user = User.find(current_user.id)
      expect(user.user_profile.main_picture).to eq('dan_m.jpg')
      expect(user.user_profile.small_picture).to eq('dan_s.jpg')

      post(:delete_images, {}, session)
      user = User.find(current_user.id)
      expect(user.user_profile.main_picture).to be_nil
      expect(user.user_profile.small_picture).to be_nil
    end
  end
end
