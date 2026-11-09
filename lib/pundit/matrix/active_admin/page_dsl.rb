module Pundit
  module Matrix
    module ActiveAdmin
      module PageDSL
        def screen(key)
          config.matrix_access = [:screen, Pundit::Matrix.screens.fetch(key).key]
        end

        def admin_screen
          config.matrix_access = [:admin]
        end

        def open_screen
          config.matrix_access = [:open]
        end
      end
    end
  end
end
