module Pundit
  module Matrix
    class RoleAssignment < ApplicationRecord
      belongs_to :role
      belongs_to :subject, polymorphic: true

      validates :role_id, uniqueness: { scope: %i[subject_type subject_id] }

      def self.ransackable_attributes(_auth_object = nil)
        searchable_by_role? ? %w[role_id] : []
      end

      def self.ransackable_associations(_auth_object = nil)
        []
      end

      ActiveSupport.run_load_hooks(:pundit_matrix_role_assignment, self)
    end
  end
end
