RSpec.describe 'ActiveAdmin adapter', type: :request do
  let(:admin) { make_admin(User.create!(email: 'admin@example.com')) }
  let(:superadmin) { make_superadmin(User.create!(email: 'super@example.com')) }

  def subject_with(**levels)
    grant_levels(User.create!(email: "#{levels.keys.join('-')}@example.com"), **levels)
  end

  def as(user, method, path, **options)
    public_send(method, path, **options, headers: { 'X-User-Id' => user.id.to_s, **options.fetch(:headers, {}) })
  end

  # A reload compiles the roles screen anew and coverage counts only the last compile, so the requests come after it.
  describe 'the registration of the roles screen' do
    let(:namespace) { ActiveAdmin.application.namespaces[:admin] }

    before { ActiveAdmin.application.load! }

    def reload
      ActiveAdmin.application.unload!
      ActiveAdmin.application.load!
    end

    def roles
      namespace.resources.select { |resource| resource.try(:resource_class) == Pundit::Matrix::Role }
    end

    it 'is one screen named Role, in the menu where the app file reopening it puts it' do
      expect(roles.map { |resource| resource.resource_name.to_s }).to eq(['Role'])
      expect(roles.first.member_actions.map(&:name)).to eq(%i[move_up move_down])

      as(admin, :get, '/admin/roles')

      menu = Nokogiri::HTML(response.body).css('#tabs > li#access > ul > li > a')
      expect(menu.map { |link| link['href'] }).to eq(%w[/admin/roles /admin/users])
    end

    it 'comes again before the app file on a reload' do
      reload

      expect(roles.size).to eq(1)
      expect(roles.first.menu_item_options).to include(parent: 'access', priority: 1)
      expect(roles.first.member_actions.map(&:name)).to eq(%i[move_up move_down])
    end

    context 'when the app registers its own' do
      around do |example|
        Pundit::Matrix.config.roles_screen = false
        reload
        example.run
      ensure
        Pundit::Matrix.config.roles_screen = true
        reload
      end

      it 'leaves the screen to the app' do
        expect(roles.size).to eq(1)
        expect(roles.first.member_actions).to be_empty
      end
    end
  end

  describe 'pages' do
    it 'opens a page meant for everyone signed in' do
      as(subject_with, :get, '/admin/dashboard')

      expect(response).to have_http_status(:ok)
    end

    it 'opens a page with the level its screen needs' do
      as(subject_with(reports: :read), :get, '/admin/reports')

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a page without the level' do
      as(subject_with(widgets: :write), :get, '/admin/reports')

      expect(response).to redirect_to('/admin')
    end

    it 'opens an admin page to admins only' do
      as(admin, :get, '/admin/audit')
      expect(response).to have_http_status(:ok)

      as(subject_with(reports: :read), :get, '/admin/audit')
      expect(response).to redirect_to('/admin')
    end

    it 'refuses a page that declares nothing, even to a superadmin' do
      as(superadmin, :get, '/admin/forgotten')

      expect(response).to redirect_to('/admin')
    end

    it 'refuses an unknown screen when the page is declared' do
      expect { ActiveAdmin::PageDSL.new(ActiveAdmin::Page.new(nil, 'X', {})).screen(:nothing) }
        .to raise_error(Pundit::Matrix::UnknownScreenError)
    end
  end

  describe 'records past the policy scope' do
    let!(:public_widget) { Widget.create!(name: 'Public') }
    let!(:secret_widget) { Widget.create!(name: 'Secret', secret: true) }

    it 'opens a record inside the scope' do
      as(subject_with(widgets: :read), :get, "/admin/widgets/#{public_widget.id}")

      expect(response).to have_http_status(:ok)
    end

    it 'does not find a record the list hides' do
      reader = subject_with(widgets: :read)

      expect { as(reader, :get, "/admin/widgets/#{secret_widget.id}") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { as(reader, :put, "/admin/widgets/#{secret_widget.id}/publish") }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'finds it for whoever the scope allows' do
      as(admin, :get, "/admin/widgets/#{secret_widget.id}")

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'refusals' do
    it 'sends someone with a screen back where they came from' do
      as(subject_with(widgets: :read), :get, '/admin/users', headers: { 'Referer' => '/admin/widgets' })

      expect(response).to redirect_to('/admin/widgets')
      expect(flash[:error]).to eq(I18n.t('active_admin.access_denied.message'))
    end

    it 'sends someone with no screen to the dashboard' do
      as(subject_with, :get, '/admin/users', headers: { 'Referer' => '/admin/widgets' })

      expect(response).to redirect_to('/admin')
      expect(flash[:error]).to eq(I18n.t('active_admin.access_denied.message'))
    end

    it 'answers other formats the way ActiveAdmin does' do
      as(subject_with, :get, '/admin/users.json')

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'the subject resource' do
    let(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator') }
    let!(:luke) { User.create!(email: 'luke@example.com').tap { |user| user.roles << operator_role } }

    def filter_names
      Nokogiri::HTML(response.body).css('.filter_form [name^="q["]').map { |input| input['name'] }
    end

    it 'offers the role filter to admins' do
      as(admin, :get, '/admin/users')

      expect(filter_names).to eq(['q[email_cont]', 'q[role_assignments_role_id_eq]'])
    end

    it 'hides the role filter from anyone else and ignores a role condition' do
      reader = subject_with(users: :read)

      as(reader, :get, '/admin/users', params: { q: { role_assignments_role_id_eq: operator_role.id } })

      expect(response).to have_http_status(:ok)
      expect(filter_names).to eq(['q[email_cont]'])
      expect(response.body).to include(reader.email, 'luke@example.com')
    end

    it 'shows the roles on the detail' do
      as(admin, :get, "/admin/users/#{luke.id}")

      expect(Nokogiri::HTML(response.body).css('#roles_sidebar_section li').map(&:text)).to eq(['Operator'])
    end

    it 'permits the roles next to what the host permits' do
      analyst = Pundit::Matrix::Role.create!(name: 'Analyst')

      params = { user: { email: 'skywalker@example.com', role_ids: ['', analyst.id], superadmin: '1' } }
      as(admin, :patch, "/admin/users/#{luke.id}", params:)

      luke.reload
      expect(luke.email).to eq('skywalker@example.com')
      expect(luke.roles).to eq([analyst])
      expect(luke).not_to be_superadmin
    end

    it 'permits the superadmin flag to a superadmin' do
      role_ids = [Pundit::Matrix::Role.admin_role.id, operator_role.id]
      as(superadmin, :patch, "/admin/users/#{luke.id}", params: { user: { superadmin: '1', role_ids: } })

      expect(luke.reload).to be_superadmin
    end

    describe 'the role inputs of the form' do
      def form
        Nokogiri::HTML(response.body).at_css('form#edit_user')
      end

      def role_boxes
        form.css('li.check_boxes input[type=checkbox][name="user[role_ids][]"]')
      end

      it 'puts the roles among the other inputs, stacked in order, with the ones the actor cannot assign disabled' do
        manager_role = Pundit::Matrix::Role.create!(name: 'Manager')
        luke.roles << manager_role

        as(admin, :get, "/admin/users/#{luke.id}/edit")

        expect(form.css('fieldset.inputs > ol > li').map { |item| item['class'].split.first })
          .to eq(%w[email check_boxes])
        expect(form.css('li.check_boxes label').map { |label| label.text.strip })
          .to include('Admin', 'Operator', 'Manager')
        expect(role_boxes.map { |box| [box['value'], box['checked'].present?, box['disabled'].present?] }).to eq(
          [
            [Pundit::Matrix::Role.admin_role.id.to_s, false, true],
            [operator_role.id.to_s, true, false],
            [manager_role.id.to_s, true, false],
          ]
        )
        expect(form.css('input[type=hidden][name="user[role_ids][]"]').map { |input| input['value'] }).to eq([''])
        expect(form.css('[name="user[superadmin]"]')).to be_empty
      end

      it 'adds the superadmin flag below the roles for a superadmin' do
        as(superadmin, :get, "/admin/users/#{luke.id}/edit")

        expect(form.css('fieldset.inputs > ol > li').map { |item| item['class'].split.first })
          .to eq(%w[email check_boxes boolean])
        expect(role_boxes.select { |box| box['disabled'] }).to be_empty
      end
    end

    it 'leaves a request without the subject alone' do
      as(admin, :patch, "/admin/users/#{luke.id}")

      expect(luke.reload.email).to eq('luke@example.com')
    end
  end

  describe 'the roles screen' do
    let!(:operator) { Pundit::Matrix::Role.create!(name: 'Operator') }
    let!(:manager) { Pundit::Matrix::Role.create!(name: 'Manager') }

    def page
      Nokogiri::HTML(response.body)
    end

    def arrows
      page.css('td.col-position a').to_h { |link| [link['href'], link.text] }
    end

    def order
      Pundit::Matrix::Role.ordered.pluck(:name)
    end

    it 'lets a superadmin list, show and build roles' do
      as(superadmin, :get, '/admin/roles')
      expect(response.body).to include('Operator')
      as(superadmin, :get, "/admin/roles/#{operator.id}")
      expect(response).to have_http_status(:ok)
      as(superadmin, :get, '/admin/roles/new')
      expect(response.body).to include('role[levels][widgets]')
    end

    it 'has no admin flag anywhere' do
      as(superadmin, :get, '/admin/roles')
      expect(response.body).not_to include('q[admin', 'col-admin')

      as(superadmin, :get, '/admin/roles/new')
      expect(response.body).not_to include('role[admin]')
    end

    it 'shows the position a new role gets and the one a role has, without letting anyone type it' do
      as(admin, :get, '/admin/roles/new')
      expect(page.at_css('#role_position')).to have_attributes(to_h: include('value' => '4', 'disabled' => 'disabled'))

      as(admin, :get, "/admin/roles/#{manager.id}/edit")
      expect(page.at_css('#role_position')).to have_attributes(to_h: include('value' => '3', 'disabled' => 'disabled'))
    end

    it 'puts the matrix into the form as one more labelled input, as wide as its levels' do
      as(admin, :get, "/admin/roles/#{manager.id}/edit")

      inputs = page.css('form fieldset.inputs')
      matrix = inputs.at_css('li.pundit-matrix-levels')
      expect(inputs.size).to eq(1)
      expect(inputs.css('> ol > li').map { |item| item['class'].split.first }).to eq(%w[string number input])
      expect(matrix['id']).to eq('role_levels_input')
      expect(matrix['class']).to eq('input optional pundit-matrix-levels')
      expect(matrix.at_css('> label.label').text).to eq('Permissions')
      expect(matrix.at_css('table')['class']).to eq('pundit-matrix')
    end

    it 'arranges the matrix by the admin menu: its groups, their order and the labels of its items' do
      as(admin, :get, "/admin/roles/#{manager.id}/edit")

      table = page.at_css('li.pundit-matrix-levels table')
      expect(table.css('th[scope=rowgroup]').map(&:text)).to eq(%w[General Access])
      expect(table.css('tbody tr td:first-child').map(&:text)).to eq(%w[Reports Gadgets Users])

      as(admin, :get, "/admin/roles/#{manager.id}")

      expect(page.css('table.pundit-matrix th[scope=row]').map(&:text)).to eq(%w[Reports Gadgets Users])
    end

    it 'shows the admin role like any other, with the levels it really has' do
      as(admin, :get, "/admin/roles/#{Pundit::Matrix::Role.admin_role.id}")

      read_only, writable = Pundit::Matrix.screens.partition(&:read_only?)
      expect(page.css('table.pundit-matrix td.pundit-matrix-write').size).to eq(writable.size)
      expect(page.css('table.pundit-matrix td.pundit-matrix-read').size).to eq(read_only.size)
    end

    it 'offers no edit of the admin role, not even to a superadmin' do
      admin_role = Pundit::Matrix::Role.admin_role

      as(superadmin, :get, '/admin/roles')
      expect(page.css('a.edit_link').map { |link| link['href'] })
        .to contain_exactly("/admin/roles/#{operator.id}/edit", "/admin/roles/#{manager.id}/edit")

      as(superadmin, :get, "/admin/roles/#{admin_role.id}")
      expect(page.css('.action_items a').map(&:text)).to be_empty

      as(superadmin, :patch, "/admin/roles/#{admin_role.id}", params: { role: { name: 'Boss' } })
      expect(admin_role.reload.name).to eq('Admin')
    end

    def breadcrumb
      page.css('.breadcrumb a').map { |link| [link.text, link['href']] }
    end

    it 'names the roles in the breadcrumb after the model' do
      plural = { one: 'Roll', other: 'Rolls' }
      I18n.backend.store_translations(:en, activerecord: { models: { 'pundit/matrix/role': plural } })

      as(admin, :get, "/admin/roles/#{manager.id}/edit")

      expect(breadcrumb)
        .to eq([['Admin', '/admin'], ['Rolls', '/admin/roles'], ['Manager', "/admin/roles/#{manager.id}"]])
    ensure
      I18n.backend.reload!
    end

    it 'falls back to the plural of the model name without a translation' do
      as(admin, :get, "/admin/roles/#{manager.id}")

      expect(breadcrumb).to eq([['Admin', '/admin'], ['Roles', '/admin/roles']])
    end

    describe 'who holds a role' do
      let!(:luke) { User.create!(email: 'luke@example.com', roles: [manager]) }

      before { make_superadmin(User.create!(email: 'yoda@example.com')) }

      it 'counts the holders of every role on the index in one query' do
        User.create!(email: 'leia@example.com', roles: [manager, operator])
        admin
        counts = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          counts << payload[:sql] if payload[:sql].match?(/COUNT.*FROM "role_assignments"/)
        end

        as(admin, :get, '/admin/roles')

        ActiveSupport::Notifications.unsubscribe(subscriber)
        shown = page.css('tbody tr').to_h { |row| [row.at_css('.col-name').text, row.at_css('.col-holders').text] }
        expect(shown).to eq('Admin' => '2', 'Operator' => '1', 'Manager' => '2')
        expect(page.at_css('th.col-holders').text).to eq(Pundit::Matrix.t('holder_count'))
        expect(counts.size).to eq(1)
      end

      it 'lists the holders on the detail, linking to those the actor may open' do
        as(admin, :get, "/admin/roles/#{Pundit::Matrix::Role.admin_role.id}")

        expect(page.css('.panel li').map { |item| [item.text, item.at_css('a')&.[]('href')] })
          .to eq([['admin@example.com', nil], ['yoda@example.com', nil]])

        as(admin, :get, "/admin/roles/#{manager.id}")

        expect(page.css('.panel h3').map(&:text)).to include(Pundit::Matrix.t('holders'))
        expect(page.css('.panel li').map { |item| [item.text, item.at_css('a')&.[]('href')] })
          .to eq([['luke@example.com', "/admin/users/#{luke.id}"]])
      end

      it 'lists them only to whoever sees who holds what, even when the app opens a role wider' do
        open_policy = Class.new(Pundit::Matrix::RolePolicy) do
          def index? = true
          def show? = true
        end
        open_policy.const_set(:Scope, Class.new(Pundit::Matrix::RolePolicy::Scope) { def resolve = @scope.all })
        stub_const('Admin::RolePolicy', open_policy)
        reader = subject_with(widgets: :read)

        as(reader, :get, "/admin/roles/#{manager.id}")

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('luke@example.com', 'Held by')
      end

      it 'says when nobody holds a role' do
        as(admin, :get, "/admin/roles/#{operator.id}")

        expect(response.body).to include('Nobody holds this role.')
      end
    end

    it 'ignores a position sent anyway' do
      as(admin, :post, '/admin/roles', params: { role: { name: 'Analyst', position: 1 } })
      as(admin, :patch, "/admin/roles/#{operator.id}", params: { role: { name: 'Operators', position: 3 } })

      expect(order).to eq(%w[Admin Operators Manager Analyst])
    end

    it 'shows the arrows a role can take, and none for the admin role' do
      as(admin, :get, '/admin/roles')

      expect(arrows).to eq(
        "/admin/roles/#{operator.id}/move_down" => '↓',
        "/admin/roles/#{manager.id}/move_up" => '↑'
      )
      expect(page.css('td.col-position a').map { |link| link['data-method'] }).to all(eq('put'))
    end

    def index_queries
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') { |*, payload| queries << payload[:sql] }
      as(admin, :get, '/admin/roles')
      queries.size
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it 'asks no more queries for the arrows of more roles' do
      index_queries
      two_roles = index_queries
      %w[Analyst Auditor Clerk].each { |name| Pundit::Matrix::Role.create!(name:) }

      expect(index_queries).to eq(two_roles)
      expect(arrows.size).to eq(8)
    end

    it 'shows no arrows in a filtered or reordered list' do
      as(admin, :get, '/admin/roles', params: { q: { name_cont: 'a' } })
      expect(arrows).to be_empty

      as(admin, :get, '/admin/roles', params: { order: 'name_asc' })
      expect(arrows).to be_empty

      as(admin, :get, '/admin/roles', params: { order: 'position_asc' })
      expect(arrows).not_to be_empty
    end

    it 'moves a role one step' do
      as(admin, :put, "/admin/roles/#{manager.id}/move_up")

      expect(response).to redirect_to('/admin/roles')
      expect(order).to eq(%w[Admin Manager Operator])

      as(admin, :put, "/admin/roles/#{manager.id}/move_down")

      expect(order).to eq(%w[Admin Operator Manager])
    end

    it 'never deletes or moves the admin role' do
      admin_role = Pundit::Matrix::Role.admin_role

      as(superadmin, :get, '/admin/roles')
      expect(page.css('a.delete_link').map { |link| link['href'] })
        .to contain_exactly("/admin/roles/#{operator.id}", "/admin/roles/#{manager.id}")

      as(superadmin, :put, "/admin/roles/#{admin_role.id}/move_down")
      expect(order).to eq(%w[Admin Operator Manager])

      as(superadmin, :delete, "/admin/roles/#{admin_role.id}")
      expect(Pundit::Matrix::Role.admin_role).to eq(admin_role)
    end

    it 'keeps roles from anyone who does not manage them' do
      writer = subject_with(widgets: :write)

      expect { as(writer, :put, "/admin/roles/#{manager.id}/move_up") }.to raise_error(ActiveRecord::RecordNotFound)
      expect(order.first(3)).to eq(%w[Admin Operator Manager])
    end

    it 'warns while nobody is an active superadmin' do
      as(admin, :get, '/admin/roles')

      expect(response.body).to include(Pundit::Matrix.t('no_superadmin'))
    end
  end
end
