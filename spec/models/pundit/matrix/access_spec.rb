RSpec.describe Pundit::Matrix::Access do
  include_context 'with fresh configuration'

  let(:user) { User.create!(email: 'a@example.com') }

  before do
    Pundit::Matrix.screens.draw do
      screen :orders
      screen :invoices
      screen :audit_log, read_only: true
    end
  end

  def create_role(name, **levels)
    Pundit::Matrix::Role.create!(name:).tap do |role|
      levels.each { |screen, level| role.permissions.create!(screen:, level:) }
    end
  end

  it 'gives no access without a role' do
    expect(user.access.level(:orders)).to eq(:none)
    expect(user.access).not_to be_read(:orders)
    expect(user.access).not_to be_write(:orders)
  end

  it 'gives the level the role has on a screen' do
    user.roles << create_role('Operator', orders: 'read')

    expect(user.access.level(:orders)).to eq(:read)
    expect(user.access).to be_read(:orders)
    expect(user.access).not_to be_write(:orders)
    expect(user.access.level(:invoices)).to eq(:none)
  end

  it 'gives the highest level from all roles of the subject' do
    user.roles << create_role('Operator', orders: 'write', invoices: 'read')
    user.roles << create_role('Accountant', orders: 'read', audit_log: 'read')

    expect(user.access.level(:orders)).to eq(:write)
    expect(user.access.level(:invoices)).to eq(:read)
    expect(user.access.level(:audit_log)).to eq(:read)
  end

  it 'gives an admin role everything the screens offer' do
    user.roles << Pundit::Matrix::Role.admin_role

    expect(user.access).to be_everything
    expect(user.access.level(:orders)).to eq(:write)
    expect(user.access.level(:audit_log)).to eq(:read)
  end

  it 'gives a superadmin everything by the flag' do
    superadmin = User.new(superadmin: true)

    expect(superadmin.access).to be_everything
    expect(superadmin.access.level(:invoices)).to eq(:write)
  end

  it 'ignores levels stored for a screen that is no longer declared' do
    user.roles << create_role('Operator', orders: 'read', invoices: 'write')
    Pundit::Matrix.instance_variable_set(:@config, Pundit::Matrix::Configuration.new)
    Pundit::Matrix.screens.draw { screen :orders }

    expect(user.access.level(:orders)).to eq(:read)
    expect { user.access.level(:invoices) }.to raise_error(Pundit::Matrix::UnknownScreenError)
  end

  it 'raises for a screen that is not declared' do
    expect { user.access.level(:removed) }.to raise_error(Pundit::Matrix::UnknownScreenError)
  end

  def count_queries(&)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') { |*, payload| queries << payload[:sql] }
    yield
    queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it 'loads the roles and levels once' do
    user.roles << create_role('Operator', orders: 'read')
    user = User.find(self.user.id)

    expect(count_queries { 3.times { user.access.read?(:orders) } }).to eq(2)
  end

  it 'needs no query for an admin role to read its levels once roles are loaded' do
    user.roles << Pundit::Matrix::Role.admin_role
    user = User.includes(:roles).find(self.user.id)

    expect(count_queries { user.access.level(:orders) }).to eq(0)
  end

  it 'checks preloaded subjects without further queries' do
    manager = create_role('Manager')
    operator = create_role('Operator')
    user.roles << manager
    3.times { |i| User.create!(email: "#{i}@example.com").roles << operator }
    user.access.position
    others = User.includes(:roles).where.not(id: user.id).to_a

    expect(count_queries { others.each { |other| user.access.manage?(other) } }).to eq(0)
  end

  it 'loads the levels again after the subject is reloaded' do
    user.access.level(:orders)
    user.roles << create_role('Operator', orders: 'write')

    expect(user.reload.access.level(:orders)).to eq(:write)
  end

  describe '#any?' do
    it 'is false without a role or with levels only on screens no longer declared' do
      expect(user.access).not_to be_any

      role = create_role('Operator')
      role.permissions.new(screen: 'old_screen', level: 'read').save!(validate: false)
      user.roles << role

      expect(user.reload.access).not_to be_any
    end

    it 'is true with read on one screen' do
      user.roles << create_role('Operator', audit_log: 'read')

      expect(user.access).to be_any
    end

    it 'is true for admins and superadmins' do
      user.roles << Pundit::Matrix::Role.admin_role

      expect(user.access).to be_any
      expect(User.new(superadmin: true).access).to be_any
    end
  end
end
