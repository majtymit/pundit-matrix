module Pundit
  module Matrix
    module ActiveAdmin
      # A resource or page of an ActiveAdmin namespace, as the matrix sees it: its screen and its place in the menu.
      class Registration
        attr_reader :resource

        def initialize(resource)
          @resource = resource
        end

        def name
          resource.resource_name.to_s
        end

        def access
          return resource.matrix_access if page?

          return [:screen, policy_class.matrix_screen] if policy_class.respond_to?(:matrix_screen)

          [:admin] if policy_class.try(:matrix_admin_screen?)
        end

        def screen
          kind, key = access
          key if kind == :screen
        end

        def in_menu?
          resource.include_in_menu?
        end

        def parent
          Array.wrap(resource.menu_item_options[:parent]).first&.to_s
        end

        def place(menu, view)
          options = resource.menu_item_options
          parent_item = parent && menu[parent]
          Layout::Place.new(
            group: parent&.parameterize(separator: '_')&.to_sym,
            group_label: parent_item ? text(view, parent_item.label) : parent,
            group_priority: parent_item&.priority,
            priority: options.fetch(:priority, 10),
            label: text(view, options[:label])
          )
        end

        private

        def page?
          resource.is_a?(::ActiveAdmin::Page)
        end

        def target
          page? ? resource : resource.resource_class
        end

        # Found the way ActiveAdmin finds it, but without building a record, which a model without a table cannot.
        def policy_class
          return @policy_class if defined?(@policy_class)

          namespace = ::ActiveAdmin.application.pundit_policy_namespace
          @policy_class = Pundit::PolicyFinder.new(namespace ? [namespace.to_sym, target] : target).policy ||
                          ::ActiveAdmin.application.pundit_default_policy&.constantize
        end

        # Menu labels may be procs rendering HTML, such as an icon before the text; the matrix shows the text.
        def text(view, label)
          label = view.instance_exec(&label) if label.is_a?(Proc)
          view.strip_tags(label.to_s).strip.presence
        end
      end
    end
  end
end
