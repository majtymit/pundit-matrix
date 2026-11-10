require_relative 'active_admin/resource_dsl'
require_relative 'active_admin/page_dsl'
require_relative 'active_admin/form_dsl'
require_relative 'active_admin/registration'
require_relative 'active_admin/screen_map'
require_relative 'active_admin/page_policy'
require_relative 'active_admin/controller'
require_relative 'active_admin/role_name'

ActiveAdmin::ResourceDSL.include(Pundit::Matrix::ActiveAdmin::ResourceDSL)
ActiveAdmin::PageDSL.include(Pundit::Matrix::ActiveAdmin::PageDSL)
ActiveAdmin::Views::ActiveAdminForm.include(Pundit::Matrix::ActiveAdmin::FormDSL)
ActiveAdmin::Page.attr_accessor(:matrix_access)
ActiveAdmin::Namespace.prepend(Pundit::Matrix::ActiveAdmin::RoleName)

# Only a view inside the admin has a menu to take the groups, order and labels from.
Pundit::Matrix.screen_places = lambda do |view|
  next {} unless view.respond_to?(:active_admin_namespace)

  Pundit::Matrix::ActiveAdmin::ScreenMap.new(view.active_admin_namespace).places(view)
end

# The controllers inherit from the host's ApplicationController, so they may load only once ActiveAdmin loads.
ActiveAdmin.after_load do
  ActiveAdmin::BaseController.include(Pundit::Matrix::ActiveAdmin::Controller)
  ActiveAdmin::ResourceController.prepend(Pundit::Matrix::ActiveAdmin::ScopedFind)
end

# Before the app's files on every load, reloads included, so an app file reopening the roles screen always comes after.
ActiveAdmin.before_load do
  load File.expand_path('active_admin/roles_screen.rb', __dir__) if Pundit::Matrix.config.roles_screen
end
