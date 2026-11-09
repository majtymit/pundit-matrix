module Pundit
  module Matrix
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true

      # Who holds which role is visible to those who manage roles, so nobody else may search subjects by role.
      def self.searchable_by_role?
        actor = Current.actor
        actor.nil? || actor.access.everything?
      end
      private_class_method :searchable_by_role?

      private

      def add_error(attribute, type)
        errors.add(attribute, type, message: Pundit::Matrix.t("errors.#{type}"))
      end
    end
  end
end
