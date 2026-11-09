module Pundit
  module Matrix
    class Permission < ApplicationRecord
      LEVELS = %w[read write].freeze

      belongs_to :role

      validates :screen, presence: true, uniqueness: { scope: :role_id }
      validates :level, inclusion: { in: LEVELS }
      validate :screen_declared_with_level
      validate :role_not_admin

      private

      def screen_declared_with_level
        return if screen.blank?
        return add_error(:screen, :screen_not_declared) unless Pundit::Matrix.screens.key?(screen)

        add_error(:level, :level_not_offered) unless Pundit::Matrix.screens.fetch(screen).levels.include?(level&.to_sym)
      end

      def role_not_admin
        add_error(:role, :admin_role) if role&.admin?
      end

      ActiveSupport.run_load_hooks(:pundit_matrix_permission, self)
    end
  end
end
