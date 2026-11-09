require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_admin'
require 'pundit/matrix'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = 'dummy'
    config.i18n.available_locales = %i[en sk]
    config.action_controller.allow_forgery_protection = false
    config.action_dispatch.show_exceptions = :none
    # No asset pipeline here; ActiveAdmin only adds its files to this list.
    config.assets = ActiveSupport::OrderedOptions.new.merge!(precompile: [])
  end
end
