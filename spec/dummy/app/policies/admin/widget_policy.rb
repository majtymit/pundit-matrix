module Admin
  class WidgetPolicy < ApplicationPolicy
    screen :widgets
    actions_of_screen :reports, :publish

    class Scope < ApplicationPolicy::Scope
      def resolve
        @user.access.everything? ? @scope.all : @scope.where(secret: false)
      end
    end
  end
end
