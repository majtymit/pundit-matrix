# frozen_string_literal: true

require 'pundit'
require_relative 'matrix/version'
require_relative 'matrix/configuration'

module Pundit
  module Matrix
    class Error < StandardError; end

    class << self
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
