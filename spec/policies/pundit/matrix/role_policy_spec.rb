RSpec.describe Pundit::Matrix::RolePolicy do
  let(:admin_role) { Pundit::Matrix::Role.admin_role }
  let(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator') }

  let(:superadmin) { make_superadmin(User.create!(email: 'super@example.com')) }
  let(:admin) { make_admin(User.create!(email: 'admin@example.com')) }
  let(:operator) { User.create!(email: 'operator@example.com').tap { |user| user.roles << operator_role } }

  let(:every_action) { %i[index? show? new? create? edit? update? destroy? move_up? move_down?] }

  def allowed(user, record)
    policy = described_class.new(user, record)
    every_action.select { |action| policy.public_send(action) }
  end

  it 'lets a superadmin do everything with an ordinary role' do
    expect(allowed(superadmin, operator_role)).to eq(every_action)
  end

  it 'lets nobody edit, delete or move the admin role, not even a superadmin' do
    expect(allowed(superadmin, admin_role)).to eq(%i[index? show? new? create?])
  end

  it 'lets an admin manage and move ordinary roles' do
    expect(allowed(admin, operator_role)).to eq(every_action)
  end

  it 'keeps the admin role away from an admin' do
    expect(allowed(admin, admin_role)).to eq(%i[index? show? new? create?])
  end

  it 'keeps roles away from an ordinary role and from nobody' do
    expect(allowed(operator, operator_role)).to be_empty
    expect(allowed(nil, operator_role)).to be_empty
  end

  it 'permits the name and the levels, never the position' do
    expect(described_class.new(superadmin, operator_role).permitted_attributes).to eq([:name, { levels: {} }])
    expect(described_class.new(admin, operator_role).permitted_attributes).to eq([:name, { levels: {} }])
  end

  it 'lists roles only for admins and superadmins' do
    operator_role

    expect(described_class::Scope.new(admin, Pundit::Matrix::Role).resolve)
      .to contain_exactly(admin_role, operator_role)
    expect(described_class::Scope.new(operator, Pundit::Matrix::Role).resolve).to be_empty
    expect(described_class::Scope.new(nil, Pundit::Matrix::Role).resolve).to be_empty
  end

  it 'is a screen for admins, outside the matrix' do
    expect(described_class).to be_matrix_admin_screen
  end
end
