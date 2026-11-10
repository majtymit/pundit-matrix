require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../active_admin/active_admin_generator'
require_relative '../generator_helpers'

module Pundit
  module Matrix
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      include GeneratorHelpers

      APPLICATION_POLICY = 'app/policies/application_policy.rb'.freeze

      source_root File.expand_path('templates', __dir__)

      argument :subject_name, type: :string, default: 'User', banner: 'MODEL'
      class_option :table_prefix, type: :string, default: '', desc: "Prefix for the gem's tables"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def check_subject
        raise Thor::Error, "Model #{subject_name} does not exist" unless subject_class
      end

      def check_tables
        existing = %w[roles permissions role_assignments].map { |table| "#{table_prefix}#{table}" }
                                                         .select { |table| connection.table_exists?(table) }
        return if existing.empty?

        raise Thor::Error, "Tables #{existing.join(', ')} already exist, choose another one with --table-prefix"
      end

      def add_superadmin_column
        return if subject_class.new.respond_to?(:superadmin?)

        migration_template 'add_superadmin.rb.tt', "db/migrate/add_superadmin_to_#{subject_table}.rb"
      end

      def copy_migration
        migration_template 'create_pundit_matrix_tables.rb.tt', 'db/migrate/create_pundit_matrix_tables.rb'
      end

      def create_initializer
        template 'initializer.rb.tt', 'config/initializers/pundit_matrix.rb'
      end

      def create_role_policy
        template 'role_policy.rb.tt', 'app/policies/role_policy.rb' unless active_admin?
      end

      def add_has_roles
        path = "app/models/#{subject_name.underscore}.rb"
        return if read(path).match?(/^\s*has_roles\b/)

        before, text = roles_insertion(read(path).lines)
        insert_into_file path, text, after: before
      end

      def extend_application_policy
        added = inject_after(
          APPLICATION_POLICY,
          /^class ApplicationPolicy\b.*\n/,
          "  extend Pundit::Matrix::Policy\n\n",
          unless_matching: /Pundit::Matrix::Policy/
        )
        return if added || exist?(APPLICATION_POLICY)

        steps << "Create #{APPLICATION_POLICY} with `extend Pundit::Matrix::Policy`."
      end

      def add_subject_screen
        return if active_admin? || declare_subject_screen("app/policies/#{subject_name.underscore}_policy.rb")

        steps << "Declare the screen in #{subject_name}Policy with `subject_screen :#{subject_key}`."
      end

      def add_active_admin
        return unless active_admin?

        @active_admin_steps = invoke(ActiveAdminGenerator, [subject_name], options.merge(next_steps: false)).last
      end

      def show_next_steps
        say "\nNext:"
        [
          'Run the migrations.',
          'Declare the screens in config/initializers/pundit_matrix.rb.',
          'Declare its screen in every other policy with `screen :key`.',
          *steps,
          *@active_admin_steps,
          'Make someone a superadmin: bin/rails pundit_matrix:superadmin EMAIL=you@example.com',
        ].each.with_index(1) { |step, number| say "  #{number}. #{step}" }
      end

      private

      def subject_class
        subject_name.safe_constantize
      end

      def subject_table
        subject_class.table_name
      end

      def active_admin?
        defined?(::ActiveAdmin)
      end

      def connection
        ActiveRecord::Base.connection
      end

      def migration_version
        ActiveRecord::Migration.current_version
      end

      def admin_role_name
        Pundit::Matrix.t('admin_role_name')
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
