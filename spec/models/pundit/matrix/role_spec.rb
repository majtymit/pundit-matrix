RSpec.describe Pundit::Matrix::Role do
  let(:admin_role) { described_class.admin_role }

  def create_roles(*names)
    names.map { |name| described_class.create!(name:) }
  end

  def order
    described_class.ordered.pluck(:name, :position)
  end

  it 'needs a name' do
    role = described_class.new

    expect(role).not_to be_valid
    expect(role.errors.attribute_names).to contain_exactly(:name)
  end

  it 'refuses a name another role already has' do
    create_roles('Operator')

    expect(described_class.new(name: 'Operator')).not_to be_valid
  end

  it 'is higher than a role with a bigger position' do
    expect(described_class.new(position: 1)).to be_higher_than(described_class.new(position: 2))
    expect(described_class.new(position: 2)).not_to be_higher_than(described_class.new(position: 1))
  end

  it 'orders roles from the highest' do
    operator, manager = create_roles('Operator', 'Manager')

    expect(described_class.ordered).to eq([admin_role, operator, manager])
  end

  describe 'the admin role' do
    it 'is the role at position 1, made by the install migration' do
      expect(admin_role).to have_attributes(name: 'Admin', position: 1)
      expect(admin_role).to be_admin
      expect(create_roles('Operator').first).not_to be_admin
    end

    it 'cannot exist twice' do
      expect(described_class.new(name: 'Second admin', position: 1)).not_to be_valid
    end

    it 'keeps position 1' do
      expect(admin_role.update(position: 2)).to be(false)
      expect(admin_role.errors[:position]).to eq(['stays 1, the admin role comes first'])
      expect(admin_role).to be_admin
    end

    it 'cannot be deleted, by anyone' do
      expect(admin_role.destroy).to be(false)
      expect(admin_role.errors[:base]).to eq(['The admin role cannot be deleted'])
      expect { admin_role.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(described_class.admin_role).to eq(admin_role)
    end

    it 'does not move' do
      create_roles('Operator')

      expect(admin_role).not_to be_movable_up
      expect(admin_role).not_to be_movable_down
      expect(admin_role.move_down).to be(false)
      expect(order.first).to eq(['Admin', 1])
    end

    it 'gets position 1 back when it is missing, while ordinary roles keep their places' do
      admin_role.delete
      create_roles('Operator')

      expect(Pundit::Matrix.admin_role!).to have_attributes(name: 'Admin', position: 1)
      expect(order).to eq([['Admin', 1], ['Operator', 2]])
    end
  end

  describe 'positions' do
    it 'gives a new role the next free position, never the one of the admin role' do
      admin_role.delete
      expect(described_class.new.position).to eq(2)

      create_roles('Operator')
      expect(described_class.new.position).to eq(3)
    end

    it 'ignores a position given by hand' do
      role = described_class.create!(name: 'Operator', position: 7)

      expect(role.position).to eq(2)
    end

    it 'refuses a change of position other than a move' do
      role, = create_roles('Operator', 'Manager')

      expect(role.update(position: 3)).to be(false)
      expect(role.errors[:position]).to include('changes only by moving the role up or down')
    end

    it 'moves a role one step up or down' do
      operator, manager, analyst = create_roles('Operator', 'Manager', 'Analyst')

      expect(analyst.move_up).to be(true)
      expect(order).to eq([['Admin', 1], ['Operator', 2], ['Analyst', 3], ['Manager', 4]])
      expect(analyst.position).to eq(3)

      expect(operator.move_down).to be(true)
      expect(order).to eq([['Admin', 1], ['Analyst', 2], ['Operator', 3], ['Manager', 4]])
      expect(manager.reload).to be_valid
    end

    it 'moves the first ordinary role no higher and the last one no lower' do
      first, last = create_roles('Operator', 'Manager')

      expect(first).not_to be_movable_up
      expect(first).to be_movable_down
      expect(last).to be_movable_up
      expect(last).not_to be_movable_down
      expect(first.move_up).to be(false)
      expect(last.move_down).to be(false)
      expect(order).to eq([['Admin', 1], ['Operator', 2], ['Manager', 3]])
    end

    it 'renumbers the whole list gapless when a role moves' do
      create_roles('Operator', 'Manager', 'Analyst')
      connection = described_class.connection
      connection.execute("UPDATE roles SET position = 9 WHERE name = 'Manager'")
      connection.execute("UPDATE roles SET position = 5 WHERE name = 'Analyst'")

      described_class.find_by!(name: 'Operator').move_down

      expect(order).to eq([['Admin', 1], ['Analyst', 2], ['Operator', 3], ['Manager', 4]])
    end

    it 'closes the gap a deleted role leaves' do
      _, manager = create_roles('Operator', 'Manager', 'Analyst')

      manager.destroy!

      expect(order).to eq([['Admin', 1], ['Operator', 2], ['Analyst', 3]])
    end
  end

  describe 'holders' do
    it 'lists the subjects holding the role' do
      operator, manager = create_roles('Operator', 'Manager')
      luke = User.create!(email: 'luke@example.com', roles: [operator])
      leia = User.create!(email: 'leia@example.com', roles: [operator, manager])

      expect(operator.holders).to contain_exactly(luke, leia)
      expect(manager.holders).to eq([leia])
    end

    it 'counts the holders of several roles at once' do
      operator, manager, analyst = create_roles('Operator', 'Manager', 'Analyst')
      User.create!(email: 'luke@example.com', roles: [operator])
      User.create!(email: 'leia@example.com', roles: [operator, manager])

      expect(described_class.holder_counts(described_class.where(id: [operator.id, analyst.id])))
        .to eq(operator.id => 2)
    end
  end

  it 'cannot be deleted while a subject holds it' do
    role, = create_roles('Operator')
    role.role_assignments.create!(subject: User.create!(email: 'a@example.com'))

    expect(role.destroy).to be(false)
    expect(role.errors[:base]).to be_present
  end

  describe 'with screens' do
    include_context 'with fresh configuration'

    it 'deletes its permissions with it' do
      Pundit::Matrix.screens.draw { screen :orders }
      role, = create_roles('Operator')
      role.permissions.create!(screen: 'orders', level: 'read')

      expect { role.destroy }.to change(Pundit::Matrix::Permission, :count).by(-1)
    end

    it 'uses the configured table prefix' do
      Pundit::Matrix.config.table_prefix = 'matrix_'

      expect(described_class.reset_table_name).to eq('matrix_roles')
    ensure
      Pundit::Matrix.config.table_prefix = ''
      described_class.reset_table_name
    end
  end

  describe '#levels' do
    include_context 'with fresh configuration'

    let(:role) { described_class.create!(name: 'Operator') }

    before do
      Pundit::Matrix.screens.draw do
        screen :orders
        screen :invoices
        screen :audit_log, read_only: true
      end
    end

    it 'saves the levels sent by a form' do
      role.update!(levels: { 'orders' => 'write', 'invoices' => 'read', 'audit_log' => 'none' })

      expect(role.reload.levels).to eq(orders: :write, invoices: :read)
    end

    it 'changes and removes levels already saved' do
      role.update!(levels: { orders: 'write', invoices: 'read' })

      role.update!(levels: { orders: 'read', invoices: 'none' })

      expect(role.reload.levels).to eq(orders: :read)
      expect(role.permissions.count).to eq(1)
    end

    it 'keeps levels not sent by the form' do
      role.update!(levels: { orders: 'write' })

      role.update!(levels: { invoices: 'read' })

      expect(role.reload.levels).to eq(orders: :write, invoices: :read)
    end

    it 'refuses a level the screen does not offer and saves nothing' do
      expect(role.update(levels: { orders: 'read', audit_log: 'write' })).to be(false)
      expect(role.reload.levels).to be_empty
    end

    it 'shows levels not saved yet' do
      role.levels = { orders: 'read' }

      expect(role.levels).to eq(orders: :read)
    end
  end

  it 'lets an admin filter roles by their own columns only' do
    expect(described_class.ransackable_attributes).to contain_exactly(
      'id',
      'name',
      'position',
      'created_at',
      'updated_at'
    )
    expect(described_class.ransackable_associations).to be_empty
  end

  it 'hides every column from an actor who does not manage roles, as any of them would reveal role holders' do
    operator = User.create!(email: 'operator@example.com')
    operator.roles << described_class.create!(name: 'Operator')

    Pundit::Matrix::Current.set(actor: operator) { expect(described_class.ransackable_attributes).to be_empty }
  end

  it 'lets the host extend it through a load hook' do
    hooked = nil
    ActiveSupport.on_load(:pundit_matrix_role) { hooked = self }

    expect(hooked).to eq(described_class)
  end

  it "leads Pundit to the host's RolePolicy, in any namespace" do
    stub_const('RolePolicy', Class.new(Pundit::Matrix::RolePolicy))
    stub_const('Admin::RolePolicy', Class.new(Pundit::Matrix::RolePolicy))

    expect(Pundit::PolicyFinder.new(described_class).policy).to eq(RolePolicy)
    expect(Pundit::PolicyFinder.new([:admin, described_class.new]).policy).to eq(Admin::RolePolicy)
  end
end
