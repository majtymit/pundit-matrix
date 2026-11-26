ENV['RAILS_ENV'] = 'test'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    minimum_coverage line: 100
  end
end

require_relative 'dummy/config/environment'
require 'rspec/rails'
require 'pundit/matrix/rspec'

Dir[File.join(__dir__, 'support/**/*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'

  config.disable_monkey_patching!

  config.use_transactional_fixtures = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
