module Pundit
  module Matrix
    module Policy
      module AdminActions
        def index?
          user.present? && user.access.everything?
        end

        def show?
          index?
        end

        def history?
          index?
        end

        def create?
          false
        end

        def new?
          create?
        end

        def update?
          false
        end

        def edit?
          update?
        end

        def destroy?
          false
        end
      end
    end
  end
end
