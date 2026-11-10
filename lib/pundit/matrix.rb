require 'pundit'
require_relative 'matrix/version'
require_relative 'matrix/screen'
require_relative 'matrix/screens'
require_relative 'matrix/configuration'
require_relative 'matrix/model'
require_relative 'matrix/policy'
require_relative 'matrix/policy/actions'
require_relative 'matrix/policy/subject_actions'
require_relative 'matrix/policy/admin_actions'
require_relative 'matrix/current'
require_relative 'matrix/controller'
require_relative 'matrix/lint'

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

      # Set up by an operator, not by anyone signed in, so it runs with no actor whatever request it is called from.
      def setup_superadmin!(subject)
        Current.set do
          Role.transaction do
            role = admin_role!
            subject.update!(superadmin: true, role_ids: subject.role_ids | [role.id])
            role
          end
        end
      end

      def admin_role!
        Role.admin_role || Role.create!(name: t('admin_role_name'), position: Role::ADMIN_POSITION)
      end
    end
  end
end

require_relative 'matrix/engine'
