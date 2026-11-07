module Pundit
  module Matrix
    class Role < ApplicationRecord
      has_many :permissions, dependent: :delete_all, autosave: true
      has_many :role_assignments, dependent: :restrict_with_error

      validates :name, presence: true, uniqueness: true
      validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
      validate :admin_role_above_ordinary_roles, if: :admin?
      validate :ordinary_role_below_admin_roles, unless: :admin?

      scope :ordered, -> { order(:position) }
      scope :admins, -> { where(admin: true) }
      scope :ordinary, -> { where(admin: false) }

      def higher_than?(other)
        position < other.position
      end

      def levels
        permissions.reject(&:marked_for_destruction?).to_h do |permission|
          [permission.screen.to_sym, permission.level.to_sym]
        end
      end

      def levels=(levels)
        levels.each do |screen, level|
          permission = permissions.find { |existing| existing.screen == screen.to_s }
          permission ||= permissions.build(screen: screen.to_s)
          level.to_s == 'none' ? permission.mark_for_destruction : permission.assign_attributes(level: level.to_s)
        end
      end

      private

      def admin_role_above_ordinary_roles
        lowest_ordinary = other_roles.ordinary.minimum(:position)
        return unless position && lowest_ordinary && position > lowest_ordinary

        add_error(:position, :above_ordinary_roles)
      end

      def ordinary_role_below_admin_roles
        highest_admin = other_roles.admins.maximum(:position)
        return unless position && highest_admin && position < highest_admin

        add_error(:position, :below_admin_roles)
      end

      def other_roles
        self.class.where.not(id:)
      end
    end
  end
end
