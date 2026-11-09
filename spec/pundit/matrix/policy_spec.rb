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

  let(:order_policy) do
    Class.new(application_policy) do
      screen :orders

      def import?
        write?
      end
    end
  end

  let(:user) { User.create!(email: 'a@example.com') }

  before { Pundit::Matrix.screens.draw { screen :orders } }

  def give(level)
    role = Pundit::Matrix::Role.create!(name: 'Operator', position: 1)
    role.permissions.create!(screen: 'orders', level:)
    user.roles << role
  end

  def allowed(user)
    policy = order_policy.new(user, :order)
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

    policy = Class.new(order_policy) do
      def destroy?
        false
      end
    end

    expect(policy.new(user, :order).destroy?).to be(false)
  end

  it 'leaves policies without a screen to the base policy' do
    give('write')

    expect(application_policy.new(user, :order).index?).to be(false)
  end

  it 'shows the history of a record to whoever writes on the screen' do
    expect(order_policy.new(user, :order).history?).to be(false)

    give('write')

    expect(order_policy.new(user.reload, :order).history?).to be(true)
  end

  describe 'actions that belong to another screen' do
    let(:setting_policy) do
      Class.new(application_policy) do
        screen :settings
        actions_of_screen :orders, :remove_overrides, 'copy_overrides'
        actions_of_screen :reports, :export

        def export?
          read?(:reports)
        end
      end
    end

    before do
      Pundit::Matrix.screens.draw do
        screen :settings
        screen :reports
      end
    end

    it 'needs write on that screen' do
      give('write')

      policy = setting_policy.new(user, :setting)
      expect([policy.remove_overrides?, policy.copy_overrides?, policy.update?]).to eq([true, true, false])
    end

    it 'keeps what the policy defines itself' do
      user.roles << Pundit::Matrix::Role.create!(name: 'Reader', position: 2, levels: { reports: 'read' })

      expect(setting_policy.new(user, :setting).export?).to be(true)
    end

    it 'declares which screen each of them belongs to' do
      expect(setting_policy.matrix_screen_actions)
        .to eq(remove_overrides: :orders, copy_overrides: :orders, export: :reports)
    end

    it 'allows nothing without a subject' do
      expect(setting_policy.new(nil, :setting).remove_overrides?).to be(false)
    end
  end

  describe 'a screen for admins only' do
    let(:trail_policy) { Class.new(application_policy) { admin_screen } }

    it 'lets admins and superadmins read it and nobody write it' do
      admin = User.create!(email: 'admin@example.com')
      admin.roles << Pundit::Matrix::Role.create!(name: 'Admin', position: 1, admin: true)
      superadmin = User.create!(email: 'super@example.com', superadmin: true)
      grant_levels(user, orders: :write)

      [admin, superadmin].each do |subject|
        policy = trail_policy.new(subject, :version)
        expect(%i[index? show? history?].map { |action| policy.public_send(action) }).to all(be(true))
        expect(%i[new? create? edit? update? destroy?].map { |action| policy.public_send(action) }).to all(be(false))
      end
      expect(trail_policy.new(user, :version).index?).to be(false)
      expect(trail_policy.new(nil, :version).index?).to be(false)
    end

    it 'keeps the screen out of the matrix' do
      expect(trail_policy).to be_matrix_admin_screen
      expect(trail_policy).not_to respond_to(:matrix_screen)
    end
  end
end
