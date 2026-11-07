module Pundit
  module Matrix
    class Engine < ::Rails::Engine
      isolate_namespace Pundit::Matrix

      initializer 'pundit_matrix.model' do
        ActiveSupport.on_load(:active_record) { extend Pundit::Matrix::Model }
      end
    end
  end
end
