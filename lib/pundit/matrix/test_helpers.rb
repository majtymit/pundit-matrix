module Pundit
  module Matrix
    module TestHelpers
      # Ordinary roles of a spec start far down, so an admin role still fits above them.
      FIRST_ORDINARY_POSITION = 1000

      def grant_levels(subject, **levels)
        position = [Role.maximum(:position).to_i, FIRST_ORDINARY_POSITION].max + 1
        give_role(subject, Role.create!(name: "Levels #{position}", position:, levels:))
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
