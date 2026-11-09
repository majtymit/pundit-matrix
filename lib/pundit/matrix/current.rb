module Pundit
  module Matrix
    module Current
      class << self
        def actor
          actor, source = state
          actor || source&.call
        end

        def set(actor: nil, actor_source: nil)
          previous = state
          self.state = [actor, actor_source]
          yield
        ensure
          self.state = previous
        end

        private

        def state
          ActiveSupport::IsolatedExecutionState[:pundit_matrix_actor]
        end

        def state=(state)
          ActiveSupport::IsolatedExecutionState[:pundit_matrix_actor] = state
        end
      end
    end
  end
end
