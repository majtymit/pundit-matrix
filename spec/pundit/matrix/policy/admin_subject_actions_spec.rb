RSpec.describe Pundit::Matrix::Policy::AdminSubjectActions do
  include_context 'with fresh configuration'

  let(:account_policy) do
    Class.new do
      extend Pundit::Matrix::Policy

      attr_reader :user, :record

      def initialize(user, record)
        @user = user
        @record = record
      end

      admin_subject_screen

      def deactivate?
        write? && manage?
      end
    end
  end

  let(:admin_role) { Pundit::Matrix::Role.admin_role }
  let(:manager_role) { Pundit::Matrix::Role.create!(name: 'Manager', levels: { users: 'write', orders: 'write' }) }
  let!(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator') }

  let(:superadmin) { create_user('super', superadmin: true) }
  let(:admin) { create_user('admin', admin_role) }
  let(:other_admin) { create_user('other-admin', admin_role) }
  let(:manager) { create_user('manager', manager_role) }
  let(:operator) { create_user('operator', operator_role) }

  before do
    Pundit::Matrix.screens.draw do
      screen :users
      screen :orders
    end
  end

  def create_user(name, *roles, superadmin: false)
    roles = [Pundit::Matrix::Role.admin_role, *roles] if superadmin
    User.create!(email: "#{name}@example.com", superadmin:, roles:)
  end

  def allowed(user, record)
    policy = account_policy.new(user, record)
    %i[index? show? new? create? edit? update? destroy? history? deactivate?]
      .select { |action| policy.public_send(action) }
  end

  it 'lets an admin list, create and change the subjects it manages' do
    expect(allowed(admin, operator)).to eq(%i[index? show? new? create? edit? update? destroy? history? deactivate?])
    expect(allowed(admin, User)).to eq(%i[index? show? new? create? edit? update? destroy? history? deactivate?])
    expect(allowed(admin, other_admin)).to eq(%i[index? new? create? history?])
    expect(allowed(admin, superadmin)).to eq(%i[index? new? create? history?])
  end

  it 'lets a superadmin change everyone' do
    expect(allowed(superadmin, admin)).to eq(%i[index? show? new? create? edit? update? destroy? history? deactivate?])
  end

  it 'allows nothing to an ordinary role, whatever its levels, and nothing without a subject' do
    expect(allowed(manager, operator)).to be_empty
    expect(allowed(nil, operator)).to be_empty
  end

  it 'still asks the matrix about another screen' do
    expect(account_policy.new(manager, operator).write?(:orders)).to be(true)
    expect(account_policy.new(admin, operator).read?(:orders)).to be(true)
    expect(account_policy.new(operator, manager).read?(:orders)).to be(false)
  end

  it 'permits roles to whoever may edit, and the flag to a superadmin only' do
    expect(account_policy.new(superadmin, operator).permitted_subject_attributes)
      .to eq([:superadmin, { role_ids: [] }])
    expect(account_policy.new(admin, operator).permitted_subject_attributes).to eq([{ role_ids: [] }])
    expect(account_policy.new(admin, other_admin).permitted_subject_attributes).to be_empty
    expect(account_policy.new(manager, operator).permitted_subject_attributes).to be_empty
  end

  it 'keeps the screen out of the matrix' do
    expect(account_policy).to be_matrix_admin_screen
    expect(account_policy).not_to respond_to(:matrix_screen)
  end
end
