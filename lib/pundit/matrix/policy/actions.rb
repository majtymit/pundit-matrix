module Pundit
  module Matrix
    module Policy
      module Actions
        def index?
          read?
        end

        def show?
          read?
        end

        def create?
          write?
        end

        def new?
          create?
        end

        def update?
          write?
        end

        def edit?
          update?
        end

        def destroy?
          write?
        end

        def read?
          user.present? && user.access.read?(matrix_screen)
        end

        def write?
          user.present? && user.access.write?(matrix_screen)
        end
      end
    end
  end
end
