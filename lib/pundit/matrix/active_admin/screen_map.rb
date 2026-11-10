module Pundit
  module Matrix
    module ActiveAdmin
      # The screens of an ActiveAdmin namespace: where its menu places them, and whether their levels match what
      # their registrations offer. The screens examples check the second.
      class ScreenMap
        # `except` names the resources and pages the app keeps outside the matrix, as the screens spec lists them.
        def initialize(namespace, except: [])
          @namespace = namespace
          @registrations =
            namespace
            .resources.map { |resource| Registration.new(resource) }
            .reject { |registration| registration.name.in?(except) }
        end

        def places(view)
          menu = @namespace.fetch_menu(::ActiveAdmin::DEFAULT_MENU)
          shown.transform_values { |registrations| registrations.first.place(menu, view) }
        end

        def conflicts
          shown.filter_map do |key, registrations|
            parents = registrations.group_by(&:parent)
            next if parents.size < 2

            under = parents.map { |parent, members| "#{parent || 'no parent'} (#{members.map(&:name).join(', ')})" }
            "Screen #{key} sits under #{under.join(' and ')}"
          end
        end

        def level_mismatches(subject)
          writes = write_actions(subject)
          (@registrations.filter_map(&:screen) | writes.keys).filter_map do |key|
            mismatch(Pundit::Matrix.screens.fetch(key), writes.fetch(key, []))
          end
        end

        private

        def shown
          @registrations.select { |registration| registration.screen && registration.in_menu? }.group_by(&:screen)
        end

        def write_actions(subject)
          @registrations.each_with_object({}) do |registration, writes|
            registration.write_actions(subject).each do |action, key|
              (writes[key] ||= []) << "#{registration.name}##{action}" if key
            end
          end
        end

        def mismatch(screen, actions)
          if screen.read_only? && actions.any?
            "Screen #{screen.key} is read-only, but these actions need write: #{actions.join(', ')}"
          elsif !screen.read_only? && actions.empty?
            "Screen #{screen.key} is writable, but none of its actions needs write"
          end
        end
      end
    end
  end
end
