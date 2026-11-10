require 'pundit/matrix/test_helpers'
require 'pundit/matrix/active_admin/screen_examples' if defined?(ActiveAdmin)

RSpec.configure do |config|
  config.include Pundit::Matrix::TestHelpers
end
