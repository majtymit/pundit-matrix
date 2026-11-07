# frozen_string_literal: true

module Pundit
  module Matrix
    class RoleAssignment < ApplicationRecord
      belongs_to :role
      belongs_to :subject, polymorphic: true

      validates :role_id, uniqueness: { scope: %i[subject_type subject_id] }
    end
  end
end
