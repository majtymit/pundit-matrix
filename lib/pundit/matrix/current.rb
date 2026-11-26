module Pundit
  module Matrix
    module Current
      # Nobody signed in, inside a request: unlike an operator without an actor, they may change no roles.
      class Nobody
        def roles
          Role.none
        end

        def superadmin?
          false
        end

        def access
          @access ||= Access.new(self)
        end
      end

      class << self
        def actor
          actor, source = state
          return actor if actor || source.nil?

          source.call || Nobody.new
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
