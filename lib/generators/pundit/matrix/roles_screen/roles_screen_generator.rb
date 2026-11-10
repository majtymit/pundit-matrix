require 'rails/generators'
require_relative '../generator_helpers'

module Pundit
  module Matrix
    class RolesScreenGenerator < Rails::Generators::Base
      include GeneratorHelpers

      INITIALIZER = 'config/initializers/pundit_matrix.rb'.freeze

      source_root File.expand_path('../../../../pundit/matrix/active_admin', __dir__)

      def copy_screen
        copy_file 'roles_screen.rb', 'app/admin/roles.rb'
      end

      def turn_off_the_gem_screen
        return if exist?(INITIALIZER) && read(INITIALIZER).match?(/^\s*config\.roles_screen = false/)

        turned_off = inject_after(
          INITIALIZER,
          /Pundit::Matrix\.configure do \|config\|\n/,
          "  # app/admin/roles.rb registers the roles screen.\n  config.roles_screen = false\n\n"
        )
        say "\nSet `config.roles_screen = false` in #{INITIALIZER}, or the gem registers its own too." unless turned_off
      end
    end
  end
end
