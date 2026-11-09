RSpec.describe Pundit::Matrix::TestHelpers do
  include_context 'with fresh configuration'

  let(:user) { User.create!(email: 'a@example.com') }

  before do
    Pundit::Matrix.screens.draw do
      screen :orders
      screen :invoices
    end
  end

  it 'gives a subject levels through a role of its own' do
    grant_levels(user, orders: :read, invoices: :write)
    grant_levels(user, orders: :write)

    expect(user.reload.access.level(:orders)).to eq(:write)
    expect(user.access.level(:invoices)).to eq(:write)
    expect(user.roles.map(&:position)).to eq([1001, 1002])
  end

  it 'makes an admin, with room above the roles of a spec' do
    grant_levels(user, orders: :read)

    expect(make_admin(user).reload.access).to be_admin
  end

  it 'makes a superadmin' do
    expect(make_superadmin(user).reload.access).to be_superadmin
  end

  it 'works whoever acts' do
    other = User.create!(email: 'b@example.com')

    Pundit::Matrix::Current.set(actor: other) { make_admin(user) }

    expect(user.reload.access).to be_admin
  end
end
