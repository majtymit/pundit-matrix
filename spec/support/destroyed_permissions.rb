# Stands in for the host's audit of the levels, the way DestroyedAssignments does for the assignments.
module DestroyedPermissions
  mattr_accessor :screens, default: []
end

ActiveSupport.on_load(:pundit_matrix_permission) do
  after_destroy { DestroyedPermissions.screens << screen }
end
