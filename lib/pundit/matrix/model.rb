module Pundit
  module Matrix
    module Model
      def has_roles(active_superadmins: -> { where(superadmin: true) })
        scope :active_superadmins, active_superadmins
        include Pundit::Matrix::Subject
      end
    end
  end
end
