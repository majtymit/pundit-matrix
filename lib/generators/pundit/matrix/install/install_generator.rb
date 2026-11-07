require 'rails/generators'
require 'rails/generators/active_record'

module Pundit
  module Matrix
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      argument :subject_name, type: :string, default: 'User', banner: 'MODEL'
      class_option :table_prefix, type: :string, default: '', desc: "Prefix for the gem's tables"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def check_subject
        raise Thor::Error, "Model #{subject_name} does not exist" unless subject_class
        return if subject_class.new.respond_to?(:superadmin?)

        raise Thor::Error, "#{subject_name} must answer superadmin?, add a boolean superadmin column or a method"
      end

      def check_tables
        existing = %w[roles permissions role_assignments].map { |table| "#{table_prefix}#{table}" }
                                                         .select { |table| connection.table_exists?(table) }
        return if existing.empty?

        raise Thor::Error, "Tables #{existing.join(', ')} already exist, choose another one with --table-prefix"
      end

      def copy_migration
        migration_template 'create_pundit_matrix_tables.rb.tt', 'db/migrate/create_pundit_matrix_tables.rb'
      end

      def create_initializer
        template 'initializer.rb.tt', 'config/initializers/pundit_matrix.rb'
      end

      def add_has_roles
        inject_into_class "app/models/#{subject_name.underscore}.rb", subject_class, "  has_roles\n"
      end

      def show_next_steps
        say <<~TEXT

          Next:
            1. Run the migration.
            2. Add `extend Pundit::Matrix::Policy` to your base policy and `screen :key` to each policy.
            3. Declare the screens in config/initializers/pundit_matrix.rb.
            4. Make someone a superadmin.
        TEXT
      end

      private

      def subject_class
        subject_name.safe_constantize
      end

      def connection
        ActiveRecord::Base.connection
      end

      def migration_version
        ActiveRecord::Migration.current_version
      end

      def table_prefix
        options[:table_prefix]
      end

      def primary_key_type
        Rails.application.config.generators.options.dig(:active_record, :primary_key_type)
      end

      def subject_id_type
        type = subject_class.columns_hash[subject_class.primary_key].type
        type unless type == :integer
      end
    end
  end
end
