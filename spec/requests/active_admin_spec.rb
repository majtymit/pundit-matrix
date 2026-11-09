RSpec.describe 'ActiveAdmin adapter', type: :request do
  let(:admin) { make_admin(User.create!(email: 'admin@example.com')) }
  let(:superadmin) { make_superadmin(User.create!(email: 'super@example.com')) }

  def subject_with(**levels)
    grant_levels(User.create!(email: "#{levels.keys.join('-')}@example.com"), **levels)
  end

  def as(user, method, path, **options)
    public_send(method, path, **options, headers: { 'X-User-Id' => user.id.to_s, **options.fetch(:headers, {}) })
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
    let(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator', position: 2) }
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
      analyst = Pundit::Matrix::Role.create!(name: 'Analyst', position: 3)

      params = { user: { email: 'skywalker@example.com', role_ids: ['', analyst.id], superadmin: '1' } }
      as(admin, :patch, "/admin/users/#{luke.id}", params:)

      luke.reload
      expect(luke.email).to eq('skywalker@example.com')
      expect(luke.roles).to eq([analyst])
      expect(luke).not_to be_superadmin
    end

    it 'permits the superadmin flag to a superadmin' do
      as(superadmin, :patch, "/admin/users/#{luke.id}", params: { user: { superadmin: '1' } })

      expect(luke.reload).to be_superadmin
    end

    it 'leaves a request without the subject alone' do
      as(admin, :patch, "/admin/users/#{luke.id}")

      expect(luke.reload.email).to eq('luke@example.com')
    end
  end

  describe 'the generated roles screen' do
    it 'lets a superadmin list, show and build roles' do
      role = Pundit::Matrix::Role.create!(name: 'Operator', position: 2)

      as(superadmin, :get, '/admin/roles')
      expect(response.body).to include('Operator')
      as(superadmin, :get, "/admin/roles/#{role.id}")
      expect(response).to have_http_status(:ok)
      as(superadmin, :get, '/admin/roles/new')
      expect(response.body).to include('role[admin]', 'role[levels][widgets]')
    end

    it 'keeps the admin flag from an admin' do
      as(admin, :get, '/admin/roles/new')

      expect(response.body).not_to include('role[admin]')
    end

    it 'warns while nobody is an active superadmin' do
      as(admin, :get, '/admin/roles')

      expect(response.body).to include(Pundit::Matrix.t('no_superadmin'))
    end
  end
end
