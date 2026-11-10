RSpec.describe Pundit::Matrix::Access do
  let(:admin_role) { Pundit::Matrix::Role.admin_role }
  let!(:manager_role) { Pundit::Matrix::Role.create!(name: 'Manager') }
  let!(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator') }

  let(:superadmin) { create_user('super', superadmin: true) }
  let(:other_superadmin) { create_user('other-super', superadmin: true) }
  let(:admin) { create_user('admin', admin_role) }
  let(:other_admin) { create_user('other-admin', admin_role) }
  let(:manager) { create_user('manager', manager_role) }
  let(:other_manager) { create_user('other-manager', manager_role) }
  let(:operator) { create_user('operator', operator_role) }
  let(:nobody) { create_user('nobody') }

  def create_user(name, *roles, superadmin: false)
    User.create!(email: "#{name}@example.com", superadmin:).tap { |user| user.roles << roles }
  end

  def managed_by(actor)
    [superadmin, other_superadmin, admin, other_admin, manager, other_manager, operator, nobody]
      .select { |other| actor.access.manage?(other) }
  end

  describe '#manage?' do
    it 'lets a superadmin manage everyone, including itself and other superadmins' do
      expect(managed_by(superadmin))
        .to eq([superadmin, other_superadmin, admin, other_admin, manager, other_manager, operator, nobody])
    end

    it 'lets an admin manage everyone below admin' do
      expect(managed_by(admin)).to eq([manager, other_manager, operator, nobody])
    end

    it 'lets an ordinary role manage only subjects with a lower role or none' do
      expect(managed_by(manager)).to eq([operator, nobody])
      expect(managed_by(operator)).to eq([nobody])
    end

    it 'lets a subject without a role manage nobody' do
      expect(managed_by(nobody)).to be_empty
    end
  end

  describe '#assign? and #assignable_roles' do
    it 'lets a superadmin assign any role' do
      expect(superadmin.access.assignable_roles).to eq([admin_role, manager_role, operator_role])
      expect(superadmin.access).to be_assign(admin_role)
    end

    it 'lets an admin assign every ordinary role' do
      expect(admin.access.assignable_roles).to eq([manager_role, operator_role])
      expect(admin.access).not_to be_assign(admin_role)
      expect(admin.access).to be_assign(manager_role)
    end

    it 'lets an ordinary role assign only lower roles' do
      expect(manager.access.assignable_roles).to eq([operator_role])
      expect(manager.access).not_to be_assign(manager_role)
      expect(manager.access).to be_assign(operator_role)
    end

    it 'lets a subject without a role assign nothing' do
      operator_role

      expect(nobody.access.assignable_roles).to be_empty
      expect(nobody.access).not_to be_assign(operator_role)
    end
  end
end
