module Pundit
  module Matrix
    class Role < ApplicationRecord
      ADMIN_POSITION = 1

      include RoleOrder

      has_many :permissions, dependent: :delete_all, autosave: true
      has_many :role_assignments, dependent: :restrict_with_error

      validates :name, presence: true, uniqueness: true
      validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true

      before_destroy :keep_admin_role, prepend: true

      def self.admin_role
        find_by(position: ADMIN_POSITION)
      end

      def self.holder_counts(roles)
        RoleAssignment.where(role_id: roles.map(&:id)).group(:role_id).count
      end

      def self.ransackable_attributes(_auth_object = nil)
        searchable_by_role? ? %w[id name position created_at updated_at] : []
      end

      def self.ransackable_associations(_auth_object = nil)
        []
      end

      # Pundit would look for Admin::Pundit::Matrix::RolePolicy in the admin namespace; this finds the host's
      # Admin::RolePolicy and RolePolicy instead.
      def self.policy_class
        'RolePolicy'
      end

      # Judged by the stored position, so a role cannot stop being the admin role by an unsaved change.
      def admin?
        (persisted? ? position_in_database : position) == ADMIN_POSITION
      end

      def holders
        role_assignments.includes(:subject).map(&:subject)
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

      def keep_admin_role
        return unless admin?

        add_error(:base, :admin_role_kept)
        throw :abort
      end

      ActiveSupport.run_load_hooks(:pundit_matrix_role, self)
    end
  end
end
