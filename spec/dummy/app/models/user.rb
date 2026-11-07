class User < ApplicationRecord
  has_roles active_superadmins: -> { where(superadmin: true, deactivated_at: nil) }
end
