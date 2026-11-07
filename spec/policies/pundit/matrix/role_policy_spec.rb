RSpec.describe Pundit::Matrix::RolePolicy do
  let(:admin_role) { Pundit::Matrix::Role.create!(name: 'Admin', position: 1, admin: true) }
  let(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator', position: 2) }

  let(:superadmin) { User.create!(email: 'super@example.com', superadmin: true) }
  let(:admin) { User.create!(email: 'admin@example.com').tap { |user| user.roles << admin_role } }
  let(:operator) { User.create!(email: 'operator@example.com').tap { |user| user.roles << operator_role } }

  def allowed(user, record)
    policy = described_class.new(user, record)
    %i[index? show? new? create? edit? update? destroy?].select { |action| policy.public_send(action) }
  end

  it 'lets a superadmin do everything with any role' do
    expect(allowed(superadmin, admin_role)).to eq(%i[index? show? new? create? edit? update? destroy?])
  end

  it 'lets an admin manage ordinary roles' do
    expect(allowed(admin, operator_role)).to eq(%i[index? show? new? create? edit? update? destroy?])
  end

  it 'keeps admin roles away from an admin' do
    expect(allowed(admin, admin_role)).to eq(%i[index? show? new? create?])
  end

  it 'keeps roles away from an ordinary role and from nobody' do
    expect(allowed(operator, operator_role)).to be_empty
    expect(allowed(nil, operator_role)).to be_empty
  end

  it 'lets only a superadmin set the admin flag' do
    expect(described_class.new(superadmin, operator_role).permitted_attributes).to include(:admin)
    expect(described_class.new(admin, operator_role).permitted_attributes).to eq([:name, :position, { levels: {} }])
  end

  it 'lists roles only for admins and superadmins' do
    operator_role

    expect(described_class::Scope.new(admin, Pundit::Matrix::Role).resolve)
      .to contain_exactly(admin_role, operator_role)
    expect(described_class::Scope.new(operator, Pundit::Matrix::Role).resolve).to be_empty
    expect(described_class::Scope.new(nil, Pundit::Matrix::Role).resolve).to be_empty
  end
end
