# frozen_string_literal: true

module Pundit
  module Matrix
    class Role < ApplicationRecord
      has_many :permissions, dependent: :delete_all
      has_many :role_assignments, dependent: :restrict_with_error

      validates :name, presence: true, uniqueness: true
      validates :position, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
      validate :admin_role_above_ordinary_roles, if: :admin?
      validate :ordinary_role_below_admin_roles, unless: :admin?

      scope :ordered, -> { order(:position) }
      scope :admins, -> { where(admin: true) }
      scope :ordinary, -> { where(admin: false) }

      def higher_than?(other)
        position < other.position
      end

      private

      def admin_role_above_ordinary_roles
        lowest_ordinary = other_roles.ordinary.minimum(:position)
        errors.add(:position, :above_ordinary_roles) if position && lowest_ordinary && position > lowest_ordinary
      end

      def ordinary_role_below_admin_roles
        highest_admin = other_roles.admins.maximum(:position)
        errors.add(:position, :below_admin_roles) if position && highest_admin && position < highest_admin
      end

      def other_roles
        self.class.where.not(id:)
      end
    end
  end
end
