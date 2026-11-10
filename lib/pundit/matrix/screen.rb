module Pundit
  module Matrix
    Screen = Data.define(:key, :group, :read_only) do
      alias_method :read_only?, :read_only

      def levels
        read_only? ? LEVELS - [:write] : LEVELS
      end

      def label
        I18n.t("pundit_matrix.screens.#{key}", default: key.to_s.humanize)
      end

      def group_label
        group ? I18n.t("pundit_matrix.groups.#{group}", default: group.to_s.humanize) : Pundit::Matrix.t('ungrouped')
      end
    end
  end
end
