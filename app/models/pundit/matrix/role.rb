module Pundit
  module Matrix
    class Role < ApplicationRecord
      ADMIN_POSITION = 1

      has_many :permissions, dependent: :delete_all, autosave: true
      has_many :role_assignments, dependent: :restrict_with_error

      attribute :position, :integer, default: -> { next_position }

      validates :name, presence: true, uniqueness: true
      validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
      validate :position_kept, on: :update

      before_validation :take_next_position, on: :create, unless: -> { position == ADMIN_POSITION }
      before_destroy :keep_admin_role, prepend: true
      after_destroy :close_gap

      scope :ordered, -> { order(:position) }

      def self.admin_role
        find_by(position: ADMIN_POSITION)
      end

      def self.next_position
        [maximum(:position).to_i, ADMIN_POSITION].max + 1
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

      def higher_than?(other)
        position < other.position
      end

      def movable_up?
        !admin? && self.class.where(position: (ADMIN_POSITION + 1)...position).exists?
      end

      def movable_down?
        !admin? && self.class.where(position: (position + 1)..).exists?
      end

      def move_up
        move_by(-1)
      end

      def move_down
        move_by(1)
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

      def take_next_position
        self.position = self.class.next_position
      end

      def position_kept
        add_error(:position, admin? ? :admin_position : :position_moved_only) if will_save_change_to_position?
      end

      def keep_admin_role
        return unless admin?

        add_error(:base, :admin_role_kept)
        throw :abort
      end

      def close_gap
        renumber(ordinary_roles)
      end

      def move_by(step)
        moved = self.class.transaction { swap_with_neighbour(step) }
        reload if moved
        moved
      end

      def swap_with_neighbour(step)
        roles = ordinary_roles
        index = roles.index(self)
        target = index + step if index
        return false unless target&.between?(0, roles.size - 1)

        roles[index], roles[target] = roles[target], roles[index]
        renumber(roles)
        true
      end

      def ordinary_roles
        self.class.where.not(position: ADMIN_POSITION).ordered.lock.to_a
      end

      # Past every position first, so the unique index never sees two roles on one position.
      def renumber(roles)
        offset = roles.map(&:position).max.to_i
        roles.each { |role| role.renumber_to(role.position + offset) }
        roles.each.with_index(ADMIN_POSITION + 1) { |role, position| role.renumber_to(position) }
      end

      protected

      # The renumber context skips the validation that refuses a changed position, and only that one.
      def renumber_to(position)
        self.position = position
        save!(context: :renumber)
      end

      ActiveSupport.run_load_hooks(:pundit_matrix_role, self)
    end
  end
end
