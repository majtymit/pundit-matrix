RSpec.describe Pundit::Matrix::Subject do
  def create_user(email, superadmin: false, **)
    roles = superadmin ? [Pundit::Matrix::Role.admin_role] : []
    User.create!(email:, superadmin:, roles:, **)
  end

  it 'gives the subject its roles' do
    role = Pundit::Matrix::Role.create!(name: 'Operator')
    user = create_user('a@example.com')
    user.roles << role

    expect(user.reload.roles).to eq([role])
  end

  it 'runs the callbacks of the assignments it drops, so the host can audit them' do
    kept = Pundit::Matrix::Role.create!(name: 'Operator')
    dropped = Pundit::Matrix::Role.create!(name: 'Analyst')
    user = create_user('a@example.com')
    user.update!(role_ids: [kept.id, dropped.id])
    DestroyedAssignments.role_ids.clear

    user.update!(role_ids: [kept.id])

    expect(DestroyedAssignments.role_ids).to eq([dropped.id])
  end

  it 'removes role assignments together with the subject' do
    user = create_user('a@example.com')
    user.roles << Pundit::Matrix::Role.create!(name: 'Operator')

    expect { user.destroy }.to change(Pundit::Matrix::RoleAssignment, :count).by(-1)
  end

  it 'allows subjects while no superadmin exists' do
    user = create_user('a@example.com')

    expect(user.update(email: 'b@example.com')).to be(true)
    expect(user.destroy).to be_destroyed
  end

  context 'with the last active superadmin' do
    let!(:superadmin) { create_user('super@example.com', superadmin: true) }

    before { create_user('former@example.com', superadmin: true, deactivated_at: Time.current) }

    it 'keeps the superadmin flag' do
      expect(superadmin.update(superadmin: false)).to be(false)
      expect(superadmin.errors[:base]).to eq(['At least one active superadmin must remain'])
      expect(superadmin.reload).to be_superadmin
    end

    it 'keeps the superadmin active' do
      expect { superadmin.update!(deactivated_at: Time.current) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(superadmin.reload.deactivated_at).to be_nil
    end

    it 'keeps the superadmin' do
      expect(superadmin.destroy).to be(false)
      expect(superadmin.errors[:base]).to eq(['At least one active superadmin must remain'])
      expect(User.exists?(superadmin.id)).to be(true)
    end

    it 'allows other changes' do
      expect(superadmin.update(email: 'new@example.com')).to be(true)
    end
  end

  context 'with another active superadmin' do
    let!(:superadmin) { create_user('super@example.com', superadmin: true) }

    before { create_user('other@example.com', superadmin: true) }

    it 'allows taking the superadmin flag away' do
      expect(superadmin.update(superadmin: false)).to be(true)
    end

    it 'allows deleting the superadmin' do
      expect(superadmin.destroy).to be_destroyed
    end
  end
end
