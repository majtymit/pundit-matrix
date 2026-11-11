module Pundit
  module Matrix
    module Policy
      # The levels of the screen itself are an admin's, while the subjects stay those the actor manages.
      module AdminSubjectActions
        def read?(screen = nil)
          screen ? super : user.present? && user.access.everything?
        end

        def write?(screen = nil)
          screen ? super : read?
        end
      end
    end
  end
end
