module Pundit
  module Matrix
    module TestHelpers
      def grant_levels(subject, **levels)
        give_role(subject, Role.create!(name: "Levels #{Role.next_position}", levels:))
      end

      def make_admin(subject)
        give_role(subject, Pundit::Matrix.admin_role!)
      end

      def make_superadmin(subject)
        Pundit::Matrix.setup_superadmin!(subject)
        subject
      end

      private

      def give_role(subject, role)
        Current.set { subject.update!(role_ids: subject.role_ids | [role.id]) }
        subject
      end
    end
  end
end
