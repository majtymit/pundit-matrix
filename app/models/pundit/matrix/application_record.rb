module Pundit
  module Matrix
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true

      private

      def add_error(attribute, type)
        errors.add(attribute, type, message: Pundit::Matrix.t("errors.#{type}"))
      end
    end
  end
end
