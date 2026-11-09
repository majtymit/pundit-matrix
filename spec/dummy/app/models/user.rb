class User < ApplicationRecord
  has_roles active_superadmins: -> { where(superadmin: true, deactivated_at: nil) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[email]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[roles role_assignments]
  end
end
