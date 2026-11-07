RSpec.describe Pundit::Matrix::Model do
  it 'treats every subject with the superadmin flag as an active superadmin by default' do
    account = Class.new(ApplicationRecord) do
      self.table_name = 'users'
      has_roles
    end
    stub_const('Account', account)
    Account.create!(email: 'a@example.com', superadmin: true)
    Account.create!(email: 'b@example.com')

    expect(Account.active_superadmins.pluck(:email)).to eq(['a@example.com'])
  end

  it 'takes the active superadmins from the subject' do
    User.create!(email: 'a@example.com', superadmin: true)
    User.create!(email: 'b@example.com', superadmin: true, deactivated_at: Time.current)

    expect(User.active_superadmins.pluck(:email)).to eq(['a@example.com'])
  end
end
