# frozen_string_literal: true

require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'pundit/matrix'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = 'dummy'
  end
end
