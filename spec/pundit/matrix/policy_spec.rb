RSpec.describe Pundit::Matrix::Policy do
  include_context 'with fresh configuration'

  let(:application_policy) do
    Class.new do
      extend Pundit::Matrix::Policy

      attr_reader :user, :record

      def initialize(user, record)
        @user = user
        @record = record
      end

      def index?
        false
      end

      def update?
        false
      end
    end
  end

  let(:branch_policy) do
    Class.new(application_policy) do
      screen :branches

      def import?
        write?
      end
    end
  end

  let(:user) { User.create!(email: 'a@example.com') }

  before { Pundit::Matrix.screens.draw { screen :branches } }

  def give(level)
    role = Pundit::Matrix::Role.create!(name: 'Operator', position: 1)
    role.permissions.create!(screen: 'branches', level:)
    user.roles << role
  end

  def allowed(user)
    policy = branch_policy.new(user, :branch)
    %i[index? show? new? create? edit? update? destroy? import?].select { |action| policy.public_send(action) }
  end

  it 'allows nothing without a level on the screen' do
    expect(allowed(user)).to be_empty
  end

  it 'allows reading with read' do
    give('read')

    expect(allowed(user)).to eq(%i[index? show?])
  end

  it 'allows everything with write' do
    give('write')

    expect(allowed(user)).to eq(%i[index? show? new? create? edit? update? destroy? import?])
  end

  it 'allows nothing without a subject' do
    expect(allowed(nil)).to be_empty
  end

  it 'keeps actions the policy defines itself' do
    give('write')

    policy = Class.new(branch_policy) do
      def destroy?
        false
      end
    end

    expect(policy.new(user, :branch).destroy?).to be(false)
  end

  it 'leaves policies without a screen to the base policy' do
    give('write')

    expect(application_policy.new(user, :branch).index?).to be(false)
  end
end
