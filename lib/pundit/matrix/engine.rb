module Pundit
  module Matrix
    class Engine < ::Rails::Engine
      isolate_namespace Pundit::Matrix

      initializer 'pundit_matrix.model' do
        ActiveSupport.on_load(:active_record) { extend Pundit::Matrix::Model }
      end

      initializer 'pundit_matrix.controller' do
        ActiveSupport.on_load(:action_controller) { include Pundit::Matrix::Controller }
      end
    end
  end
end
