module Pundit
  module Matrix
    module Policy
      module SubjectActions
        def show?
          read? && manage?
        end

        def update?
          write? && manage?
        end

        def destroy?
          write? && manage?
        end

        def manage?
          user.present? && (record.is_a?(Class) || user.access.manage?(record))
        end

        def permitted_subject_attributes
          return [] unless write? && manage?

          user.access.superadmin? ? [:superadmin, { role_ids: [] }] : [{ role_ids: [] }]
        end
      end
    end
  end
end
