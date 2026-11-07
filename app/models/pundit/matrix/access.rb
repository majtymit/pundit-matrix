module Pundit
  module Matrix
    class Access
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
        @subject.superadmin? || admin?
      end

      private

      def admin?
        rows.any? { |admin, _screen, _level| admin }
      end

      def levels
        @levels ||= rows.each_with_object({}) do |(_admin, screen, level), levels|
          next unless screen

          key = screen.to_sym
          level = level.to_sym
          levels[key] = level if LEVELS.index(level) > LEVELS.index(levels.fetch(key, :none))
        end
      end

      def rows
        @rows ||= @subject.roles.left_joins(:permissions).pluck(
          Role.arel_table[:admin],
          Permission.arel_table[:screen],
          Permission.arel_table[:level]
        )
      end
    end
  end
end
