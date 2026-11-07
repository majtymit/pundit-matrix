RSpec.describe Pundit::Matrix::Permission do
  include_context 'with fresh configuration'

  let(:role) { Pundit::Matrix::Role.create!(name: 'Operator', position: 1) }

  before do
    Pundit::Matrix.screens.draw do
      screen :branches
      screen :audit_versions, read_only: true
    end
  end

  it 'stores read or write for a declared screen' do
    expect(role.permissions.new(screen: 'branches', level: 'read')).to be_valid
    expect(role.permissions.new(screen: 'branches', level: 'write')).to be_valid
  end

  it 'refuses any other level' do
    permission = role.permissions.new(screen: 'branches', level: 'none')

    expect(permission).not_to be_valid
    expect(permission.errors.attribute_names).to eq([:level])
  end

  it 'refuses a screen that is not declared' do
    permission = role.permissions.new(screen: 'reservations', level: 'read')

    expect(permission).not_to be_valid
    expect(permission.errors[:screen]).to eq(['is not declared'])
  end

  it "explains errors in the gem's English when the app has no translation" do
    permission = role.permissions.new(screen: 'reservations', level: 'read')

    I18n.with_locale(:sk) { permission.valid? }

    expect(permission.errors[:screen]).to eq(['is not declared'])
  end

  it 'refuses write on a read-only screen' do
    permission = role.permissions.new(screen: 'audit_versions', level: 'write')

    expect(permission).not_to be_valid
    expect(permission.errors[:level]).to eq(['is not offered on this screen'])
  end

  it 'refuses a second level for the same screen' do
    role.permissions.create!(screen: 'branches', level: 'read')

    expect(role.permissions.new(screen: 'branches', level: 'write')).not_to be_valid
  end

  it 'refuses an admin role, which has every permission already' do
    admin = Pundit::Matrix::Role.create!(name: 'Admin', position: 2, admin: true)
    permission = admin.permissions.new(screen: 'branches', level: 'read')

    expect(permission).not_to be_valid
    expect(permission.errors[:role]).to eq(['has every permission already'])
  end
end
