module Admin
  class WidgetPolicy < ApplicationPolicy
    screen :widgets
    actions_of_screen :users, :publish

    class Scope < ApplicationPolicy::Scope
      def resolve
        @user.access.everything? ? @scope.all : @scope.where(secret: false)
      end
    end
  end
end
