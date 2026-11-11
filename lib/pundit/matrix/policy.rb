module Pundit
  module Matrix
    module Policy
      def screen(key)
        key = key.to_sym
        include Actions
        define_singleton_method(:matrix_screen) { key }
      end

      def subject_screen(key)
        screen(key)
        include SubjectActions
      end

      def admin_screen
        include AdminActions
        define_singleton_method(:matrix_admin_screen?) { true }
      end

      def admin_subject_screen
        include Actions
        include SubjectActions
        include AdminSubjectActions
        define_singleton_method(:matrix_admin_screen?) { true }
      end

      # The actions get a default in a module of their own, so a method the policy defines itself still wins.
      def actions_of_screen(screen, *actions)
        screen = screen.to_sym
        actions = actions.map(&:to_sym)
        include(Module.new do
          actions.each do |action|
            define_method(:"#{action}?") { user.present? && user.access.write?(screen) }
          end
        end)
        declared = respond_to?(:matrix_screen_actions) ? matrix_screen_actions : {}
        define_singleton_method(:matrix_screen_actions) { declared.merge(actions.index_with { screen }) }
      end
    end
  end
end
