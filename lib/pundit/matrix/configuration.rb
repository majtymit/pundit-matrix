module Pundit
  module Matrix
    class Configuration
      ROLE_MANAGERS = %i[admin superadmin].freeze

      attr_accessor :table_prefix, :roles_screen
      attr_reader :roles_managed_by

      def initialize
        @table_prefix = ''
        @roles_screen = true
        @roles_managed_by = :admin
        @screens = Screens.new
      end

      def screens(&)
        block_given? ? @screens.draw(&) : @screens
      end

      def roles_managed_by=(manager)
        manager = manager.to_sym
        unless ROLE_MANAGERS.include?(manager)
          raise ArgumentError, "roles_managed_by is :admin or :superadmin, not #{manager.inspect}"
        end

        @roles_managed_by = manager
      end
    end
  end
end
