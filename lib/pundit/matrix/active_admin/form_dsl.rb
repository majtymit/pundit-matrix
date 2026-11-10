module Pundit
  module Matrix
    module ActiveAdmin
      module FormDSL
        def matrix_subject_inputs
          actor = Current.actor
          roles = Role.ordered.to_a
          collection = roles.map { |role| [role.name, role.id] }

          input(:roles, as: :check_boxes, collection:, disabled: unassignable_role_ids(actor, roles))
          input :superadmin, as: :boolean if actor&.access&.superadmin?
        end

        # One more input of the role form: labelled like the others and as wide as its levels, not the whole form.
        def matrix_levels_input
          role = form_builder.object
          li class: 'input optional pundit-matrix-levels', id: "#{form_builder.object_name}_levels_input" do
            text_node form_builder.label(:levels, Role.human_attribute_name(:permissions), class: 'label', for: nil)
            text_node helpers.render('pundit/matrix/levels_fields', role:)
          end
        end

        private

        # Held but not assignable roles stay checked and disabled, so the form does not send them and the subject
        # keeps them.
        def unassignable_role_ids(actor, roles)
          return [] unless actor

          roles.reject { |role| actor.access.assign?(role) }.map(&:id)
        end
      end
    end
  end
end
