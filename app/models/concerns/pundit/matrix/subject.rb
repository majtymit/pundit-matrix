module Pundit
  module Matrix
    module Subject
      extend ActiveSupport::Concern

      included do
        has_many :role_assignments, as: :subject, class_name: 'Pundit::Matrix::RoleAssignment', dependent: :delete_all
        has_many :roles, through: :role_assignments, class_name: 'Pundit::Matrix::Role'

        around_save :keep_an_active_superadmin
        before_destroy :keep_an_active_superadmin_on_destroy, prepend: true
      end

      private

      def keep_an_active_superadmin
        was_active_superadmin = persisted? && active_superadmins.exists?(id)
        yield
        return unless was_active_superadmin && !active_superadmins.exists?(id) && !other_active_superadmins.exists?

        errors.add(:base, :last_superadmin)
        raise ActiveRecord::RecordInvalid, self
      end

      def keep_an_active_superadmin_on_destroy
        return unless active_superadmins.exists?(id) && !other_active_superadmins.exists?

        errors.add(:base, :last_superadmin)
        throw :abort
      end

      def active_superadmins
        self.class.instance_exec(&Pundit::Matrix.config.active_superadmins)
      end

      def other_active_superadmins
        active_superadmins.where.not(id:)
      end
    end
  end
end
