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

        def history?
          write?
        end

        def read?(screen = matrix_screen)
          user.present? && user.access.read?(screen)
        end

        def write?(screen = matrix_screen)
          user.present? && user.access.write?(screen)
        end

        private

        def matrix_screen
          self.class.matrix_screen
        end
      end
    end
  end
end
