RSpec.describe Pundit::Matrix::RoleAssignment do
  let(:role) { Pundit::Matrix::Role.create!(name: 'Operator', position: 1) }
  let(:user) { User.create!(email: 'a@example.com') }

  it 'assigns a role to any subject' do
    assignment = described_class.create!(role:, subject: user)

    expect(assignment.subject).to eq(user)
  end

  it 'assigns the same role to a subject only once' do
    described_class.create!(role:, subject: user)

    expect(described_class.new(role:, subject: user)).not_to be_valid
  end

  it 'lets an admin filter subjects by role only' do
    expect(described_class.ransackable_attributes).to eq(['role_id'])
    expect(described_class.ransackable_associations).to be_empty
  end

  it 'lets the host extend it through a load hook' do
    hooked = nil
    ActiveSupport.on_load(:pundit_matrix_role_assignment) { hooked = self }

    expect(hooked).to eq(described_class)
  end
end
