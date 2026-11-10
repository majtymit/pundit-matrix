module Pundit
  module Matrix
    # How the matrix shows its screens: in groups, in order, with labels. What the initializer and the translations
    # declare wins; the places an admin adapter takes from its menu fill in the rest.
    class Layout
      Group = Data.define(:label, :rows)
      Row = Data.define(:screen, :label)
      Place = Data.define(:group, :group_label, :group_priority, :priority, :label)

      LAST = Float::INFINITY

      def initialize(places = {})
        @places = places
      end

      def groups
        grouped = Pundit::Matrix.screens.each_with_index.group_by { |screen, _index| group_of(screen) }
        return [Group.new(nil, rows(grouped[nil]))] if grouped.keys == [nil]

        grouped.sort_by { |group, entries| order(group, entries) }.map { |group, entries| group_with(group, entries) }
      end

      private

      def order(group, entries)
        [group_priority(group, entries.map(&:first)), entries.first.last]
      end

      def group_with(group, entries)
        Group.new(group_label(group, entries.map(&:first)), rows(entries))
      end

      def group_of(screen)
        screen.group || @places[screen.key]&.group
      end

      # Ungrouped screens are top-level items of the menu, so they take their place among its groups.
      def group_priority(group, screens)
        places = places_in(group, screens)
        priorities = group ? places.map(&:group_priority) : places.map(&:priority)
        priorities.compact.min || LAST
      end

      def group_label(group, screens)
        return Pundit::Matrix.t('ungrouped') unless group

        translated("groups.#{group}") || places_in(group, screens).first&.group_label || group.to_s.humanize
      end

      def places_in(group, screens)
        screens.filter_map { |screen| @places[screen.key] }.select { |place| group.nil? || place.group == group }
      end

      def rows(entries)
        entries.sort_by { |screen, index| [@places[screen.key]&.priority || LAST, index] }
               .map { |screen, _index| Row.new(screen, label(screen)) }
      end

      def label(screen)
        translated("screens.#{screen.key}") || @places[screen.key]&.label || screen.label
      end

      def translated(key)
        I18n.t("pundit_matrix.#{key}", default: nil)
      end
    end
  end
end
