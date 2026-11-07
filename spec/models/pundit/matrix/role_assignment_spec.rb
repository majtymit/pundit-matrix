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
end
