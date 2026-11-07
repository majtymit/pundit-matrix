RSpec.describe Pundit::Matrix::Access do
  include_context 'with fresh configuration'

  let(:user) { User.create!(email: 'a@example.com') }

  before do
    Pundit::Matrix.screens.draw do
      screen :branches
      screen :reservations
      screen :audit_versions, read_only: true
    end
  end

  def create_role(name, position, admin: false, **levels)
    Pundit::Matrix::Role.create!(name:, position:, admin:).tap do |role|
      levels.each { |screen, level| role.permissions.create!(screen:, level:) }
    end
  end

  it 'gives no access without a role' do
    expect(user.access.level(:branches)).to eq(:none)
    expect(user.access).not_to be_read(:branches)
    expect(user.access).not_to be_write(:branches)
  end

  it 'gives the level the role has on a screen' do
    user.roles << create_role('Operator', 2, branches: 'read')

    expect(user.access.level(:branches)).to eq(:read)
    expect(user.access).to be_read(:branches)
    expect(user.access).not_to be_write(:branches)
    expect(user.access.level(:reservations)).to eq(:none)
  end

  it 'gives the highest level from all roles of the subject' do
    user.roles << create_role('Operator', 2, branches: 'write', reservations: 'read')
    user.roles << create_role('Accountant', 3, branches: 'read', audit_versions: 'read')

    expect(user.access.level(:branches)).to eq(:write)
    expect(user.access.level(:reservations)).to eq(:read)
    expect(user.access.level(:audit_versions)).to eq(:read)
  end

  it 'gives an admin role everything the screens offer' do
    user.roles << create_role('Admin', 1, admin: true)

    expect(user.access).to be_everything
    expect(user.access.level(:branches)).to eq(:write)
    expect(user.access.level(:audit_versions)).to eq(:read)
  end

  it 'gives a superadmin everything without a role' do
    user.update!(superadmin: true)

    expect(user.access).to be_everything
    expect(user.access.level(:reservations)).to eq(:write)
  end

  it 'ignores levels stored for a screen that is no longer declared' do
    user.roles << create_role('Operator', 2, branches: 'read', reservations: 'write')
    Pundit::Matrix.instance_variable_set(:@config, Pundit::Matrix::Configuration.new)
    Pundit::Matrix.screens.draw { screen :branches }

    expect(user.access.level(:branches)).to eq(:read)
    expect { user.access.level(:reservations) }.to raise_error(Pundit::Matrix::UnknownScreenError)
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
    user.roles << create_role('Operator', 2, branches: 'read')
    user = User.find(self.user.id)

    expect(count_queries { 3.times { user.access.read?(:branches) } }).to eq(2)
  end

  it 'needs no query for an admin role to read its levels once roles are loaded' do
    user.roles << create_role('Admin', 1, admin: true)
    user = User.includes(:roles).find(self.user.id)

    expect(count_queries { user.access.level(:branches) }).to eq(0)
  end

  it 'checks preloaded subjects without further queries' do
    manager = create_role('Manager', 2)
    operator = create_role('Operator', 3)
    user.roles << manager
    3.times { |i| User.create!(email: "#{i}@example.com").roles << operator }
    user.access.position
    others = User.includes(:roles).where.not(id: user.id).to_a

    expect(count_queries { others.each { |other| user.access.manage?(other) } }).to eq(0)
  end

  it 'loads the levels again after the subject is reloaded' do
    user.access.level(:branches)
    user.roles << create_role('Operator', 2, branches: 'write')

    expect(user.reload.access.level(:branches)).to eq(:write)
  end
end
