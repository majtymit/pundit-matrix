module Pundit
  module Matrix
    module Subject
      extend ActiveSupport::Concern

      included do
        has_many :role_assignments, as: :subject, class_name: 'Pundit::Matrix::RoleAssignment', dependent: :delete_all
        # dependent: :destroy makes `role_ids=` destroy the assignments it drops instead of deleting them past
        # their callbacks, where the host's audit hooks in.
        has_many :roles, through: :role_assignments, class_name: 'Pundit::Matrix::Role', dependent: :destroy

        around_save :keep_an_active_superadmin
        before_destroy :keep_an_active_superadmin_on_destroy, prepend: true
        validate :role_change_allowed
        validate :superadmin_change_allowed
      end

      def access
        @access ||= Pundit::Matrix::Access.new(self)
      end

      def reload(*)
        @access = nil
        @role_change_errors = nil
        super
      end

      def role_ids=(ids)
        Current.actor ? self.roles = Role.find(Array(ids).compact_blank) : super
      end

      # Held roles the actor cannot assign are kept, because a form shows them disabled and does not send them.
      def roles=(roles)
        actor = acting_subject
        if actor
          roles = roles.to_a | self.roles.reject { |role| actor.access.assign?(role) }
          @role_change_errors = role_change_errors(actor, roles)
          super(roles) if @role_change_errors.empty?
        else
          super
        end
      end

      private

      def role_change_errors(actor, roles)
        added = roles - self.roles
        return [] if added.empty? && (self.roles - roles).empty?
        return [[:base, actor == self ? :own_roles : :roles_not_managed]] unless actor.access.manage?(self)

        added.reject { |role| actor.access.assign?(role) }.map { |role| [:roles, :role_not_assignable, role.name] }
      end

      def role_change_allowed
        @role_change_errors&.each do |attribute, type, role|
          errors.add(attribute, type, message: Pundit::Matrix.t("errors.#{type}", role:))
        end
      end

      def superadmin_change_allowed
        return unless will_save_change_to_attribute?(:superadmin)

        actor = acting_subject
        return if actor.nil? || actor.access.superadmin?

        errors.add(:superadmin, :superadmin_only, message: Pundit::Matrix.t('errors.superadmin_only'))
      end

      # Acting on itself, the subject must be judged by what is stored, not by the changes it is about to save.
      def acting_subject
        actor = Current.actor
        actor.equal?(self) ? self.class.find(id) : actor
      end

      def keep_an_active_superadmin
        was_active_superadmin = persisted? && active_superadmins.exists?(id)
        yield
        return unless was_active_superadmin && !active_superadmins.exists?(id) && !other_active_superadmins.exists?

        errors.add(:base, :last_superadmin, message: Pundit::Matrix.t('errors.last_superadmin'))
        raise ActiveRecord::RecordInvalid, self
      end

      def keep_an_active_superadmin_on_destroy
        return unless active_superadmins.exists?(id) && !other_active_superadmins.exists?

        errors.add(:base, :last_superadmin, message: Pundit::Matrix.t('errors.last_superadmin'))
        throw :abort
      end

      def active_superadmins
        self.class.active_superadmins
      end

      def other_active_superadmins
        active_superadmins.where.not(id:)
      end
    end
  end
end
