module Pundit
  module Matrix
    module Lint
      class << self
        def policies_without_screen(base, except: [])
          policies(base).reject { |policy| settled?(policy) } - except
        end

        def unused_screens(base)
          used = policies(base).select { |policy| policy.respond_to?(:matrix_screen) }.map(&:matrix_screen)
          Pundit::Matrix.screens.map(&:key) - used
        end

        private

        def settled?(policy)
          policy.respond_to?(:matrix_screen) || policy.respond_to?(:matrix_admin_screen?)
        end

        # Policies load lazily, so only an eager load finds every one of them.
        def policies(base)
          Rails.application.eager_load!
          base.descendants.select(&:name).sort_by(&:name)
        end
      end
    end
  end
end
