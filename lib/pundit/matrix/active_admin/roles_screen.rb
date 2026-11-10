ActiveAdmin.register Pundit::Matrix::Role do
  config.sort_order = 'position_asc'

  permit_params do
    role_policy.permitted_attributes
  end

  # ActiveAdmin names the roles crumb after activerecord.models.role, which the namespaced model does not answer.
  breadcrumb do
    roles = Pundit::Matrix::Role.model_name
    breadcrumb_links.tap do |links|
      links[1] = link_to(roles.human(count: 2, default: roles.human.pluralize), collection_path) if links[1]
    end
  end

  controller do
    helper_method :role_policy, :role_order_shown?, :holders_shown?, :holder_counts, :subjects

    def role_policy
      active_admin_authorization.retrieve_policy(Pundit::Matrix::Role)
    end

    # Moving a role in a filtered or reordered list would pass neighbours the list does not show.
    def role_order_shown?
      params[:q].blank? && params.fetch(:order, 'position_asc') == 'position_asc'
    end

    def holders_shown?
      current_active_admin_user.access.everything?
    end

    def holder_counts
      @holder_counts ||= Pundit::Matrix::Role.holder_counts(collection)
    end

    # Whoever opens the roles screen is a subject, so their model is the one whose superadmins count.
    def subjects
      current_active_admin_user.class.base_class
    end
  end

  member_action :move_up, method: :put do
    resource.move_up
    redirect_to collection_path
  end

  member_action :move_down, method: :put do
    resource.move_down
    redirect_to collection_path
  end

  filter :name

  sidebar :superadmin, only: :index, if: -> { !subjects.active_superadmins.exists? } do
    render 'pundit/matrix/superadmin_warning', subjects:
  end

  index do
    column :name
    column :position do |role|
      span role.position
      if role_order_shown?
        if role.movable_up? && authorized?(:move_up, role)
          up = active_admin_config.route_member_action_path(:move_up, role)
          a '↑', href: up, 'data-method': :put, title: Pundit::Matrix.t('move_up')
        end
        if role.movable_down? && authorized?(:move_down, role)
          down = active_admin_config.route_member_action_path(:move_down, role)
          a '↓', href: down, 'data-method': :put, title: Pundit::Matrix.t('move_down')
        end
      end
    end
    column(Pundit::Matrix.t('holder_count')) { |role| holder_counts.fetch(role.id, 0) } if holders_shown?
    actions
  end

  show do
    attributes_table do
      row :name
      row :position
    end

    # Inside .attributes_table, the levels line up with the details above them.
    panel Pundit::Matrix::Role.human_attribute_name(:permissions) do
      div(class: 'attributes_table') { render 'pundit/matrix/levels', role: resource }
    end

    if holders_shown?
      panel Pundit::Matrix.t('holders') do
        holders = resource.holders.sort_by { |holder| display_name(holder) }
        if holders.any?
          ul { holders.each { |holder| li auto_link(holder) } }
        else
          para Pundit::Matrix.t('no_holders')
        end
      end
    end
  end

  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)

    f.inputs do
      f.input :name
      f.input :position, input_html: { disabled: true }
      f.matrix_levels_input
    end

    f.actions
  end
end
