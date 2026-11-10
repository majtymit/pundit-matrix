module Pundit
  module Matrix
    module RoleOrder
      extend ActiveSupport::Concern

      included do
        attribute :position, :integer, default: -> { next_position }

        validate :position_kept, on: :update

        before_validation :take_next_position, on: :create, unless: -> { position == Role::ADMIN_POSITION }
        after_destroy :close_gap

        scope :ordered, -> { order(:position) }
      end

      class_methods do
        def next_position
          [maximum(:position).to_i, Role::ADMIN_POSITION].max + 1
        end
      end

      def higher_than?(other)
        position < other.position
      end

      def movable_up?
        !admin? && self.class.where(position: (Role::ADMIN_POSITION + 1)...position).exists?
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

      private

      def take_next_position
        self.position = self.class.next_position
      end

      def position_kept
        add_error(:position, admin? ? :admin_position : :position_moved_only) if will_save_change_to_position?
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
        self.class.where.not(position: Role::ADMIN_POSITION).ordered.lock.to_a
      end

      # Past every position first, so the unique index never sees two roles on one position.
      def renumber(roles)
        offset = roles.map(&:position).max.to_i
        roles.each { |role| role.renumber_to(role.position + offset) }
        roles.each.with_index(Role::ADMIN_POSITION + 1) { |role, position| role.renumber_to(position) }
      end

      protected

      # The renumber context skips the validation that refuses a changed position, and only that one.
      def renumber_to(position)
        self.position = position
        save!(context: :renumber)
      end
    end
  end
end
