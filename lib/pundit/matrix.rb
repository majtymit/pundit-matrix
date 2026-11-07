require 'pundit'
require_relative 'matrix/version'
require_relative 'matrix/screen'
require_relative 'matrix/screens'
require_relative 'matrix/configuration'
require_relative 'matrix/model'

module Pundit
  module Matrix
    LEVELS = %i[none read write].freeze

    class Error < StandardError; end
    class UnknownScreenError < Error; end

    class << self
      delegate :screens, to: :config

      def config
        @config ||= Configuration.new
      end

      def configure
        yield config
      end

      def table_name_prefix
        config.table_prefix
      end
    end
  end
end

require_relative 'matrix/engine'
