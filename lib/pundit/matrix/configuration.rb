module Pundit
  module Matrix
    class Configuration
      attr_accessor :table_prefix, :roles_screen

      def initialize
        @table_prefix = ''
        @roles_screen = true
        @screens = Screens.new
      end

      def screens(&)
        block_given? ? @screens.draw(&) : @screens
      end
    end
  end
end
