require 'spec_helper'

describe IndexController do
  render_views
  describe 'index' do
    it 'should load' do
      get :index
      response.should be_success
    end

    it 'should display articles' do
      Article.should_receive(:frontpage_gossip).and_return([
        Article.new(
          :title => 'Title',
          :created_at => Time.now,
          :excerpt => 'blah, blah..'
        )
      ])
      visit '/'
      page.should have_selector("strong.gossip") do |content|
        content.should have_text('Title')
      end
    end
  end
end
