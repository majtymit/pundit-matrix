require 'pundit'
require_relative 'matrix/version'
require_relative 'matrix/screen'
require_relative 'matrix/screens'
require_relative 'matrix/configuration'
require_relative 'matrix/model'
require_relative 'matrix/policy'
require_relative 'matrix/policy/actions'
require_relative 'matrix/policy/subject_actions'
require_relative 'matrix/current'
require_relative 'matrix/controller'

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

      def t(key, **)
        I18n.t("pundit_matrix.#{key}", **, default: I18n.t("pundit_matrix.#{key}", **, locale: :en))
      end
    end
  end
end

require_relative 'matrix/engine'
