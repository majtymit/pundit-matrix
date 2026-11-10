module Pundit
  module Matrix
    module ActiveAdmin
      # ActiveAdmin names a resource after its class, so the engine's model would sit at /admin/pundit_matrix_roles,
      # and an app reopening the roles screen without `as: 'Role'` would register a second one.
      module RoleName
        def register(resource_class, options = {}, &)
          options = { as: 'Role' }.merge(options) if resource_class == Role
          super
        end
      end
    end
  end
end
