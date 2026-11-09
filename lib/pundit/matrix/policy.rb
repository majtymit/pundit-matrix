module Pundit
  module Matrix
    module Policy
      def screen(key)
        key = key.to_sym
        include Actions
        define_method(:matrix_screen) { key }
        private :matrix_screen
      end

      def subject_screen(key)
        screen(key)
        include SubjectActions
      end
    end
  end
end
