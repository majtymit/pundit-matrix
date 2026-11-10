module Pundit
  module Matrix
    module ActiveAdmin
      # A resource or page of an ActiveAdmin namespace, as the matrix sees it: its screen, its place in the menu and
      # the actions of it that need write.
      class Registration
        STANDARD_WRITES = %w[create update destroy].freeze

        # Write on every screen, so asking a policy leaves out only the actions it switches off itself: on a
        # read-only screen nobody has write, and the actions it still offers would never show up otherwise.
        class WriteEverywhere < SimpleDelegator
          def access
            self
          end

          def level(_key)
            :write
          end

          %i[read? write? manage? assign?].each { |name| define_method(name) { |_other| true } }
          %i[everything? any? superadmin?].each { |name| define_method(name) { true } }
        end

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

        # Each action that needs write and that the policy does not switch off, with the screen it counts for.
        def write_actions(subject)
          return [] if screen.nil? && moved_actions.empty?

          policy = policy_class.new(WriteEverywhere.new(subject), target)
          candidate_actions
            .select { |action| allowed?(policy, action) }
            .map { |action| [action, moved_actions.fetch(action.to_sym, screen)] }
        end

        private

        def moved_actions
          policy_class.try(:matrix_screen_actions) || {}
        end

        def page?
          resource.is_a?(::ActiveAdmin::Page)
        end

        def candidate_actions
          return non_get(resource.page_actions) if page?

          (STANDARD_WRITES & resource.controller.action_methods.to_a) +
            non_get(resource.member_actions + resource.collection_actions)
        end

        def non_get(actions)
          actions
            .reject { |action| Array(action.http_verb).all? { |verb| verb.to_sym == :get } }
            .map { |action| action.name.to_s }
        end

        def allowed?(policy, action)
          predicate = :"#{action}?"
          policy.respond_to?(predicate) && policy.public_send(predicate)
        end

        # Asked about the class, the way a policy says whether an action exists at all; asked about a row, it says
        # whether that row allows it, and a new record would answer as the blankest row.
        def target
          page? ? resource : resource.resource_class
        end

        # Found the way ActiveAdmin finds it, but without building a record, which a model without a table cannot.
        def policy_class
          return @policy_class if defined?(@policy_class)

          namespace = ::ActiveAdmin.application.pundit_policy_namespace
          @policy_class = Pundit::PolicyFinder.new(
            namespace ? [namespace.to_sym, target] : target
          ).policy || ::ActiveAdmin.application.pundit_default_policy&.constantize
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
