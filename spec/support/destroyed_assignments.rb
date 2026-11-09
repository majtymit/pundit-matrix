# Stands in for the host's audit: a callback on the assignment, added the way a host adds one.
module DestroyedAssignments
  mattr_accessor :role_ids, default: []
end

ActiveSupport.on_load(:pundit_matrix_role_assignment) do
  after_destroy { DestroyedAssignments.role_ids << role_id }
end
