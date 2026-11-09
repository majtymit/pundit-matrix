require 'rails/generators'
require_relative '../generator_helpers'

module Pundit
  module Matrix
    class ActiveAdminGenerator < Rails::Generators::Base
      include GeneratorHelpers

      INITIALIZER = 'config/initializers/active_admin.rb'.freeze
      DASHBOARD = 'app/admin/dashboard.rb'.freeze

      source_root File.expand_path('templates', __dir__)

      argument :subject_name, type: :string, default: 'User', banner: 'MODEL'
      class_option :namespace, type: :string, default: 'admin', desc: 'ActiveAdmin and policy namespace'
      class_option :next_steps, type: :boolean, default: true, hide: true

      def create_resource
        template 'roles.rb.tt', 'app/admin/roles.rb'
      end

      def create_policies
        template 'role_policy.rb.tt', "app/policies/#{namespace}/role_policy.rb"
      end

      def create_page_policy
        path = "app/policies/#{namespace}/active_admin/page_policy.rb"
        before = read(path) if exist?(path)
        template 'page_policy.rb.tt', path
        steps << page_policy_step(path, kept: read(path) == before) if before
      end

      def add_subject_screen
        path = "app/policies/#{namespace}/#{subject_name.demodulize.underscore}_policy.rb"
        return if declare_subject_screen(path)

        steps << "Declare the screen in #{namespace.camelize}::#{subject_name.demodulize}Policy with " \
                 "`subject_screen :#{subject_key}`."
      end

      def wire_refusals
        wired = inject_after(
          INITIALIZER,
          /ActiveAdmin\.setup do \|config\|\n/,
          "  config.on_unauthorized_access = :pundit_matrix_access_denied\n",
          unless_matching: /^\s*config\.on_unauthorized_access\s*=/
        )
        return if wired

        steps << "Point `config.on_unauthorized_access` in #{INITIALIZER} to `:pundit_matrix_access_denied`, " \
                 'or keep your own handler.'
      end

      def open_dashboard
        opened = inject_after(DASHBOARD, /ActiveAdmin\.register_page ['"]Dashboard['"] do\n/, "  open_screen\n\n")
        steps << 'Declare `open_screen` in the Dashboard page.' unless opened
      end

      def add_matrix_subject
        file = "app/admin/#{subject_name.underscore.pluralize}.rb"
        added = inject_after(file, /ActiveAdmin\.register #{subject_name} do\n/, "  matrix_subject\n\n")
        steps << "Add `matrix_subject` to `ActiveAdmin.register #{subject_name}`." unless added
      end

      def create_screens_spec
        return unless exist?('spec')

        template 'screens_spec.rb.tt', "spec/requests/#{namespace}/pundit_matrix_screens_spec.rb"
        return if devise?

        steps << "Adjust `create_subject` and `sign_in` in spec/requests/#{namespace}/pundit_matrix_screens_spec.rb."
      end

      # Run from the install generator, it hands its steps over, so the developer reads one list.
      def show_next_steps
        next_steps = [
          "Put the roles into the #{subject_name} form, inside `f.inputs`: " \
          "`li { render 'pundit/matrix/subject_fields', subject: f.object }`.",
          'Declare a screen in every other `register_page`: `screen :key`, `admin_screen` or `open_screen`.',
          *steps,
        ]
        return next_steps unless options[:next_steps]

        say "\nNext:"
        next_steps.each.with_index(1) { |step, number| say "  #{number}. #{step}" }
      end

      private

      def namespace
        options[:namespace]
      end

      def page_policy_step(path, kept:)
        if kept
          "#{path} was kept; inherit it from Pundit::Matrix::ActiveAdmin::PagePolicy, or the declarations " \
            'in `register_page` are not read.'
        else
          "#{path} was replaced; what it decided now belongs in each `register_page` " \
            '(`screen :key`, `admin_screen` or `open_screen`).'
        end
      end

      def devise?
        defined?(::Devise)
      end

      def factory_bot?
        exist?('spec/factories')
      end
    end
  end
end
