RSpec.describe Pundit::Matrix::Controller, type: :controller do
  context 'with Pundit' do
    controller(ActionController::Base) do
      include Pundit::Authorization

      def index
        render plain: Pundit::Matrix::Current.actor&.email.to_s
      end

      private

      def pundit_user
        User.find_by(email: request.headers['X-Email'])
      end
    end

    it 'takes the actor from pundit_user' do
      User.create!(email: 'a@example.com')
      request.headers['X-Email'] = 'a@example.com'

      get :index

      expect(response.body).to eq('a@example.com')
    end

    it 'forgets the actor after the request' do
      get :index

      expect(Pundit::Matrix::Current.actor).to be_nil
    end
  end

  context 'without Pundit' do
    controller(ActionController::Base) do
      def index
        render plain: Pundit::Matrix::Current.actor.inspect
      end
    end

    it 'sets no actor' do
      get :index

      expect(response.body).to eq('nil')
    end
  end
end
