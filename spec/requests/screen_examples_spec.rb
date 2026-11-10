RSpec.describe 'Pundit::Matrix screens of the admin', type: :request do
  def sign_in(subject)
    cookies[:user_id] = subject.id.to_s
  end

  it_behaves_like 'Pundit::Matrix screens',
                  namespace: :admin,
                  except: %w[Comment Forgotten],
                  create_subject: -> { User.create!(email: "subject-#{SecureRandom.hex(6)}@example.test") }
end
