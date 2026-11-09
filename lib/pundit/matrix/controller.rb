module Pundit
  module Matrix
    module Controller
      extend ActiveSupport::Concern

      included do
        around_action :with_pundit_matrix_actor, if: -> { is_a?(Pundit::Authorization) }
      end

      private

      # Resolved on first use, so the host's own authentication has run by then.
      def with_pundit_matrix_actor(&)
        Current.set(actor_source: -> { pundit_user }, &)
      end
    end
  end
end
