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

      def any?
        everything? || Pundit::Matrix.screens.any? { |screen| levels.key?(screen.key) }
      end

      def admin?
        roles.any?(&:admin?)
      end

      def position
        roles.map(&:position).min
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

      def roles
        @subject.roles.to_a
      end

      def levels
        @levels ||= stored_levels.each_with_object({}) do |(screen, level), levels|
          key = screen.to_sym
          level = level.to_sym
          levels[key] = level if LEVELS.index(level) > LEVELS.index(levels.fetch(key, :none))
        end
      end

      def stored_levels
        Permission.where(role: roles).pluck(:screen, :level)
      end
    end
  end
end
