RSpec.describe Pundit::Matrix::Subject do
  let(:admin_role) { Pundit::Matrix::Role.admin_role }
  let!(:manager_role) { Pundit::Matrix::Role.create!(name: 'Manager') }
  let!(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator') }
  let!(:analyst_role) { Pundit::Matrix::Role.create!(name: 'Analyst') }

  let(:superadmin) { create_user('super', superadmin: true) }
  let(:admin) { create_user('admin', admin_role) }
  let(:manager) { create_user('manager', manager_role) }
  let(:operator) { create_user('operator', operator_role) }

  def create_user(name, *roles, superadmin: false)
    User.create!(email: "#{name}@example.com", superadmin:).tap { |user| user.roles << roles }
  end

  def as(actor, &)
    Pundit::Matrix::Current.set(actor:, &)
  end

  def role_names(user)
    User.find(user.id).roles.map(&:name).sort
  end

  it 'restricts nothing without an actor' do
    operator.update!(role_ids: [admin_role.id], superadmin: true)

    expect(role_names(operator)).to eq(['Admin'])
    expect(operator.reload).to be_superadmin

    operator.roles = [manager_role]

    expect(role_names(operator)).to eq(['Manager'])
  end

  it 'lets a superadmin assign any role' do
    as(superadmin) { expect(operator.update(role_ids: [admin_role.id, analyst_role.id])).to be(true) }

    expect(role_names(operator)).to eq(%w[Admin Analyst])
  end

  it 'lets a manager assign lower roles to a lower subject' do
    as(manager) { expect(operator.update(role_ids: [analyst_role.id])).to be(true) }

    expect(role_names(operator)).to eq(['Analyst'])
  end

  it 'refuses a role the actor cannot assign' do
    as(manager) do
      expect(operator.update(role_ids: [manager_role.id, admin_role.id])).to be(false)
      expect(operator.errors.full_messages).to eq(
        [
          'Roles include Manager, which you cannot assign',
          'Roles include Admin, which you cannot assign',
        ]
      )
    end

    expect(role_names(operator)).to eq(['Operator'])
  end

  it 'refuses a subject the actor does not manage' do
    other_manager = create_user('other-manager', manager_role)

    as(manager) { expect(other_manager.update(role_ids: [operator_role.id])).to be(false) }

    expect(other_manager.errors[:base]).to eq(['Only someone with a higher role can change these roles'])
    expect(role_names(other_manager)).to eq(['Manager'])
  end

  it 'keeps held roles the actor cannot assign when the form leaves them out' do
    as(admin) { expect(admin.update(role_ids: [''], email: 'new@example.com')).to be(true) }

    expect(role_names(admin)).to eq(['Admin'])
  end

  it 'refuses a subject changing its own roles' do
    as(admin) { expect(admin.update(role_ids: [admin_role.id, manager_role.id])).to be(false) }

    expect(admin.errors[:base]).to eq(['Only a superadmin can change their own roles'])
    expect(role_names(admin)).to eq(['Admin'])
  end

  it 'lets a superadmin change its own roles' do
    as(superadmin) { expect(superadmin.update(role_ids: [admin_role.id])).to be(true) }

    expect(role_names(superadmin)).to eq(['Admin'])
  end

  it 'holds for roles= too, and for a new subject' do
    user = User.new(email: 'new@example.com')

    as(manager) do
      user.roles = [admin_role]
      expect(user.save).to be(false)
      user.roles = [analyst_role]
      expect(user.save).to be(true)
    end

    expect(role_names(user)).to eq(['Analyst'])
  end

  it 'forgets a refused change on reload' do
    as(manager) do
      operator.role_ids = [admin_role.id]
      expect(operator.reload).to be_valid
    end
  end

  it 'raises on a role that does not exist, like Rails does' do
    as(manager) { expect { operator.role_ids = [0] }.to raise_error(ActiveRecord::RecordNotFound) }
  end

  describe 'the superadmin flag' do
    it 'can be changed by a superadmin' do
      as(superadmin) { expect(operator.update(superadmin: true)).to be(true) }
    end

    it 'cannot be changed by anyone else' do
      as(admin) { expect(manager.update(superadmin: true)).to be(false) }

      expect(manager.errors.full_messages).to eq(['Superadmin can be changed only by a superadmin'])
      expect(manager.reload).not_to be_superadmin
    end

    it 'is judged by what is stored when the actor changes itself' do
      as(admin) do
        admin.superadmin = true
        expect(admin.save).to be(false)
      end
    end

    it 'lets a superadmin give up its own flag' do
      create_user('other-super', superadmin: true)

      as(superadmin) do
        superadmin.superadmin = false
        expect(superadmin.save).to be(true)
      end
    end
  end
end
