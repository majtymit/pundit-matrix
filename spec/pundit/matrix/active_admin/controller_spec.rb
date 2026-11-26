RSpec.describe Pundit::Matrix::ActiveAdmin::Controller, type: :controller do
  controller(ActionController::Base) do
    include Pundit::Matrix::ActiveAdmin::Controller

    def index
      render plain: Pundit::Matrix::Current.actor.email
    end

    private

    def current_active_admin_user
      User.find_by(email: request.headers['X-Email'])
    end
  end

  it 'takes the actor from the admin user, without Pundit::Authorization' do
    User.create!(email: 'admin@example.com')
    request.headers['X-Email'] = 'admin@example.com'

    get :index

    expect(response.body).to eq('admin@example.com')
  end
end
