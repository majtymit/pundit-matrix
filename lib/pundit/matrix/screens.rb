module Pundit
  module Matrix
    class Screens
      include Enumerable

      def initialize
        @screens = {}
      end

      def draw(&)
        instance_eval(&)
        self
      end

      def group(key, &)
        raise ArgumentError, "Group #{@group.inspect} cannot contain another group" if @group

        @group = key.to_sym
        instance_eval(&)
      ensure
        @group = nil
      end

      def screen(key, read_only: false)
        key = key.to_sym
        raise ArgumentError, "Screen #{key.inspect} is already declared" if @screens.key?(key)

        @screens[key] = Screen.new(key:, group: @group, read_only:)
      end

      def each(&)
        @screens.each_value(&)
      end

      # Without any group there is no heading at all; once there is one, ungrouped screens get a heading too, so they
      # do not read as part of the group above them.
      def by_group
        groups = group_by(&:group)
        return [[nil, to_a]] if groups.keys == [nil]

        groups.map { |_group, screens| [screens.first.group_label, screens] }
      end

      def fetch(key)
        @screens.fetch(key.to_sym) { raise UnknownScreenError, "Screen #{key.inspect} is not declared" }
      end

      def key?(key)
        @screens.key?(key.to_sym)
      end
    end
  end
end
