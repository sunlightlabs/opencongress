require 'spec_helper'

describe ProfileController do
  fixtures :users
  let(:current_user) { User.find_by_login('dan') }
  let(:session) do
    { :user => current_user.id }
  end

  describe 'upload_pic' do
    it 'uploads an avatar in 2 sizes' do
      post(:upload_pic,
           { :picture => {'tmp_file' => fixture_file_upload('/files/avatar.jpg', 'image/jpeg')}},
           session
      )
      user = User.find(current_user.id)
      user.main_picture.should == 'dan_m.jpg'
      user.small_picture.should == 'dan_s.jpg'
    end
  end

  describe 'delete_images' do
    it 'deletes both avatars' do
      post(:upload_pic,
           { :picture => {'tmp_file' => fixture_file_upload('/files/avatar.jpg', 'image/jpeg')}},
           session
      )
      user = User.find(current_user.id)
      user.main_picture.should == 'dan_m.jpg'
      user.small_picture.should == 'dan_s.jpg'

      post(:delete_images, {}, session)
      user = User.find(current_user.id)
      user.main_picture.should be_nil
      user.small_picture.should be_nil
    end
  end
end
