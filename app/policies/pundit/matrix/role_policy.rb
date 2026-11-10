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

      # The admin role has a fixed position and every permission, so there is nothing left to edit.
      def update?
        manager? && !record.admin?
      end

      def edit?
        update?
      end

      def destroy?
        update?
      end

      def move_up?
        update?
      end

      def move_down?
        update?
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
    end
  end
end
