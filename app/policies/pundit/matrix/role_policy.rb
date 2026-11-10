module Pundit
  module Matrix
    class RolePolicy
      attr_reader :user, :record

      def self.matrix_admin_screen?
        true
      end

      def initialize(user, record)
        @user = user
        @record = record
      end

      def index?
        manager?
      end

      def show?
        manager?
      end

      def create?
        manager?
      end

      def new?
        create?
      end

      def update?
        manager? && (superadmin? || !record.admin?)
      end

      def edit?
        update?
      end

      def destroy?
        ordinary_role_manager?
      end

      def move_up?
        ordinary_role_manager?
      end

      def move_down?
        ordinary_role_manager?
      end

      def permitted_attributes
        [:name, { levels: {} }]
      end

      class Scope
        def initialize(user, scope)
          @user = user
          @scope = scope
        end

        def resolve
          @user&.access&.everything? ? @scope.all : @scope.none
        end
      end

      private

      def manager?
        user.present? && user.access.everything?
      end

      def ordinary_role_manager?
        manager? && !record.admin?
      end

      def superadmin?
        user.present? && user.access.superadmin?
      end
    end
  end
end
