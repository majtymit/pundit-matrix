module Pundit
  module Matrix
    Screen = Data.define(:key, :group, :read_only) do
      alias_method :read_only?, :read_only

      def levels
        read_only? ? LEVELS - [:write] : LEVELS
      end
    end
  end
end
