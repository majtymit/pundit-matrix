module Pundit
  module Matrix
    module ActiveAdmin
      module Controller
        # Someone with no screen at all would be sent back to where they were refused, so they go to the dashboard.
        # So does someone who came from the very page that refused them, or it would send them to itself forever.
        def pundit_matrix_access_denied(exception)
          if current_active_admin_user&.access&.any? && request.referer != request.url
            return rescue_active_admin_access_denied(exception)
          end

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

      # A save can take away the actor's own access to the record, as a superadmin dropping their own flag or a role
      # dropping its own screen, and the detail would then refuse the redirect that follows it.
      module ReachableRedirect
        def smart_resource_url
          active_admin_authorization.user&.reload
          return super if authorized?(::ActiveAdmin::Auth::READ, resource)
          return collection_url if authorized?(::ActiveAdmin::Auth::READ, active_admin_config.resource_class)

          active_admin_root
        end
      end
    end
  end
end
