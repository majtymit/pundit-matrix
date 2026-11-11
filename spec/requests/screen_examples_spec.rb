RSpec.describe 'Pundit::Matrix screens of the admin', type: :request do
  def sign_in(subject)
    cookies[:user_id] = subject.id.to_s
  end

  screens = {
    namespace: :admin,
    except: %w[Comment Forgotten],
    create_subject: -> { User.create!(email: "subject-#{SecureRandom.hex(6)}@example.test") },
  }

  it_behaves_like 'Pundit::Matrix screens', **screens

  context 'when the subjects are an admin screen' do
    before { stub_const('Admin::UserPolicy', Class.new(ApplicationPolicy) { admin_subject_screen }) }

    it_behaves_like 'Pundit::Matrix screens', **screens
  end

  context 'when roles are managed by superadmins only' do
    around do |example|
      Pundit::Matrix.config.roles_managed_by = :superadmin
      example.run
    ensure
      Pundit::Matrix.config.roles_managed_by = :admin
    end

    it_behaves_like 'Pundit::Matrix screens', **screens
  end
end
