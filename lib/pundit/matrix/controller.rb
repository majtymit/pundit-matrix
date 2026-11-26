module Pundit
  module Matrix
    module Controller
      extend ActiveSupport::Concern

      included do
        around_action :with_pundit_matrix_actor, if: :pundit_matrix_actor?
      end

      private

      def pundit_matrix_actor?
        is_a?(Pundit::Authorization)
      end

      def pundit_matrix_actor
        pundit_user
      end

      # Resolved on first use, so the host's own authentication has run by then.
      def with_pundit_matrix_actor(&)
        Current.set(actor_source: -> { pundit_matrix_actor }, &)
      end
    end
  end
end
