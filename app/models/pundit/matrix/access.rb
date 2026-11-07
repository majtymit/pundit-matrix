module Pundit
  module Matrix
    class Access
      delegate :superadmin?, to: :@subject

      def initialize(subject)
        @subject = subject
      end

      def level(key)
        screen = Pundit::Matrix.screens.fetch(key)
        return screen.levels.last if everything?

        levels.fetch(screen.key, :none)
      end

      def read?(key)
        level(key) != :none
      end

      def write?(key)
        level(key) == :write
      end

      def everything?
        superadmin? || admin?
      end

      def admin?
        rows.any? { |admin, *| admin }
      end

      def position
        rows.filter_map { |_admin, position, *| position }.min
      end

      def manage?(other)
        return true if superadmin?
        return false if position.nil? || other.access.superadmin? || other.access.admin?

        other.access.position.nil? || other.access.position > position
      end

      def assign?(role)
        return true if superadmin?

        !role.admin? && !position.nil? && role.position > position
      end

      def assignable_roles
        return Role.ordered if superadmin?
        return Role.none if position.nil?

        Role.ordinary.where(Role.arel_table[:position].gt(position)).ordered
      end

      private

      def levels
        @levels ||= rows.each_with_object({}) do |(_admin, _position, screen, level), levels|
          next unless screen

          key = screen.to_sym
          level = level.to_sym
          levels[key] = level if LEVELS.index(level) > LEVELS.index(levels.fetch(key, :none))
        end
      end

      def rows
        @rows ||= @subject.roles.left_joins(:permissions).pluck(
          Role.arel_table[:admin],
          Role.arel_table[:position],
          Permission.arel_table[:screen],
          Permission.arel_table[:level]
        )
      end
    end
  end
end
