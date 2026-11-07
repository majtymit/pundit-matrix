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
        return errors.add(:screen, :not_declared) unless Pundit::Matrix.screens.key?(screen)

        errors.add(:level, :not_offered) unless Pundit::Matrix.screens.fetch(screen).levels.include?(level&.to_sym)
      end

      def role_not_admin
        errors.add(:role, :admin) if role&.admin?
      end
    end
  end
end
