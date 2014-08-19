require 'action_controller'
require 'active_support/dependencies'

module RendersTemplates
  class DummyController < AbstractController::Base
    include AbstractController::Rendering
    include AbstractController::Layouts
    include AbstractController::Helpers
    include AbstractController::Translation
    include AbstractController::ViewPaths
    include AbstractController::AssetPaths
    include AbstractController::Logger
    include ActionDispatch::Routing
    include Rails.application.routes.url_helpers

    helper ApplicationHelper

    self.assets_dir = "#{Rails.root}/public"
    self.javascripts_dir = "#{assets_dir}/javascripts"
    self.stylesheets_dir = "#{assets_dir}/stylesheets"

    def _render(args=nil)
      render_to_string args
    end

    def params
      {}
    end

    ActiveSupport.run_load_hooks(:dummy_controller, self)
  end

  def get_renderer
    @@controller ||= DummyController.new
  end

  def render_to_string(args=nil)
    get_renderer._render args
  end
end