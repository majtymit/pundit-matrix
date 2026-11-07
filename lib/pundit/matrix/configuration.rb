module Pundit
  module Matrix
    class Configuration
      attr_accessor :table_prefix

      def initialize
        @table_prefix = ''
        @screens = Screens.new
      end

      def screens(&)
        block_given? ? @screens.draw(&) : @screens
      end
    end
  end
end
