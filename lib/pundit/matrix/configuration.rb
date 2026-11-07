module Pundit
  module Matrix
    class Configuration
      attr_accessor :subject_class, :table_prefix, :active_superadmins

      def initialize
        @subject_class = 'User'
        @table_prefix = ''
        @active_superadmins = -> { where(superadmin: true) }
        @screens = Screens.new
      end

      def screens(&)
        block_given? ? @screens.draw(&) : @screens
      end
    end
  end
end
