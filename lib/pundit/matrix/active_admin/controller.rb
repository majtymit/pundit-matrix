module Pundit
  module Matrix
    module ActiveAdmin
      module Controller
        # Someone with no screen at all would be sent back to where they were refused, so they go to the dashboard.
        def pundit_matrix_access_denied(exception)
          return rescue_active_admin_access_denied(exception) if current_active_admin_user&.access&.any?

          respond_to do |format|
            format.html { redirect_to active_admin_root, flash: { error: exception.message } }
            format.any { rescue_active_admin_access_denied(exception) }
          end
        end
      end

      module ScopedFind
        protected

        # ActiveAdmin finds a single record past the policy scope, so a typed address would open a row the list hides.
        def find_resource
          apply_authorization_scope(scoped_collection).public_send(method_for_find, params[:id])
        end
      end
    end
  end
end
