module Pundit
  module Matrix
    module ActiveAdmin
      # The screens of an ActiveAdmin namespace and where its menu places them.
      class ScreenMap
        def initialize(namespace)
          @namespace = namespace
          @registrations = namespace.resources.map { |resource| Registration.new(resource) }
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

        private

        def shown
          @registrations.select { |registration| registration.screen && registration.in_menu? }.group_by(&:screen)
        end
      end
    end
  end
end
