ActiveAdmin.register Widget do
  menu priority: 5, label: 'Gadgets'

  permit_params :name

  member_action :publish, method: :put do
    redirect_to admin_widget_path(resource)
  end
end
