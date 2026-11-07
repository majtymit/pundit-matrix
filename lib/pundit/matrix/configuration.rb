# frozen_string_literal: true

module Pundit
  module Matrix
    class Configuration
      attr_accessor :subject_class, :table_prefix

      def initialize
        @subject_class = 'User'
        @table_prefix = ''
      end
    end
  end
end
