RSpec.describe Pundit::Matrix::Role do
  def create_role(name, position, admin: false)
    described_class.create!(name:, position:, admin:)
  end

  it 'needs a name and a positive position' do
    role = described_class.new(position: 0)

    expect(role).not_to be_valid
    expect(role.errors.attribute_names).to contain_exactly(:name, :position)
  end

  it 'refuses a name or position another role already has' do
    create_role('Operator', 2)

    role = described_class.new(name: 'Operator', position: 2)

    expect(role).not_to be_valid
    expect(role.errors.attribute_names).to contain_exactly(:name, :position)
  end

  it 'is higher than a role with a bigger position' do
    expect(described_class.new(position: 1)).to be_higher_than(described_class.new(position: 2))
    expect(described_class.new(position: 2)).not_to be_higher_than(described_class.new(position: 1))
  end

  it 'orders roles from the highest' do
    operator = create_role('Operator', 3)
    admin = create_role('Admin', 1, admin: true)
    manager = create_role('Manager', 2)

    expect(described_class.ordered).to eq([admin, manager, operator])
  end

  describe 'admin roles' do
    before do
      create_role('Admin', 2, admin: true)
      create_role('Operator', 4)
    end

    it 'keeps an admin role above every ordinary role' do
      role = described_class.new(name: 'Another admin', position: 5, admin: true)

      expect(role).not_to be_valid
      expect(role.errors[:position]).to eq(['must be above every ordinary role'])
    end

    it 'keeps an ordinary role below every admin role' do
      role = described_class.new(name: 'Manager', position: 1)

      expect(role).not_to be_valid
      expect(role.errors[:position]).to eq(['must be below every admin role'])
    end

    it 'allows roles in between' do
      expect(described_class.new(name: 'Another admin', position: 1, admin: true)).to be_valid
      expect(described_class.new(name: 'Manager', position: 3)).to be_valid
    end
  end

  it 'cannot be deleted while a subject holds it' do
    role = create_role('Operator', 1)
    role.role_assignments.create!(subject: User.create!(email: 'a@example.com'))

    expect(role.destroy).to be(false)
    expect(role.errors[:base]).to be_present
  end

  describe 'with screens' do
    include_context 'with fresh configuration'

    it 'deletes its permissions with it' do
      Pundit::Matrix.screens.draw { screen :orders }
      role = create_role('Operator', 1)
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

    let(:role) { described_class.create!(name: 'Operator', position: 2) }

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
      'admin',
      'created_at',
      'updated_at'
    )
    expect(described_class.ransackable_associations).to be_empty
  end

  it 'lets the host extend it through a load hook' do
    hooked = nil
    ActiveSupport.on_load(:pundit_matrix_role) { hooked = self }

    expect(hooked).to eq(described_class)
  end
end
