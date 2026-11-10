require_relative 'active_admin/resource_dsl'
require_relative 'active_admin/page_dsl'
require_relative 'active_admin/form_dsl'
require_relative 'active_admin/page_policy'
require_relative 'active_admin/controller'

ActiveAdmin::ResourceDSL.include(Pundit::Matrix::ActiveAdmin::ResourceDSL)
ActiveAdmin::PageDSL.include(Pundit::Matrix::ActiveAdmin::PageDSL)
ActiveAdmin::Views::ActiveAdminForm.include(Pundit::Matrix::ActiveAdmin::FormDSL)
ActiveAdmin::Page.attr_accessor(:matrix_access)

# The controllers inherit from the host's ApplicationController, so they may load only once ActiveAdmin loads.
ActiveAdmin.after_load do
  ActiveAdmin::BaseController.include(Pundit::Matrix::ActiveAdmin::Controller)
  ActiveAdmin::ResourceController.prepend(Pundit::Matrix::ActiveAdmin::ScopedFind)
end
