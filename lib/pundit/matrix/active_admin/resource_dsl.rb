module Pundit
  module Matrix
    module ActiveAdmin
      module ResourceDSL
        def matrix_subject
          config.singleton_class.prepend(SubjectFilters)
          controller { prepend SubjectParams }
          sidebar :roles, only: :show do
            ul do
              resource.roles.sort_by(&:position).each { |role| li role.name }
            end
          end
        end
      end

      # Ransack refuses roles to anyone who does not manage them, and ActiveAdmin cannot render a filter Ransack
      # refuses, so the role filters show only to admins and superadmins, declared or default.
      module SubjectFilters
        ROLE_FILTER = {
          as: :select,
          collection: -> { Pundit::Matrix::Role.ordered.pluck(:name, :id) },
        }.freeze
        VISIBLE = { if: proc { current_active_admin_user&.access&.everything? } }.freeze

        private

        def filter_lookup
          filters = super
          filters[:roles] = ROLE_FILTER.merge(filters.fetch(:roles, {}), VISIBLE)
          filters[:role_assignments] = filters[:role_assignments].merge(VISIBLE) if filters.key?(:role_assignments)
          filters
        end
      end

      module SubjectParams
        private

        def permitted_params
          permitted = super
          key = active_admin_config.param_key.to_sym
          return permitted unless params[key]

          policy = active_admin_authorization.retrieve_policy(active_admin_config.resource_class)
          extra = params.require(key).permit(*policy.permitted_subject_attributes)
          permitted.merge(key => permitted.fetch(key, {}).merge(extra))
        end
      end
    end
  end
end
