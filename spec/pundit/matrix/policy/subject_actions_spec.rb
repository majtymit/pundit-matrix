RSpec.describe Pundit::Matrix::Policy::SubjectActions do
  include_context 'with fresh configuration'

  let(:user_policy) do
    Class.new do
      extend Pundit::Matrix::Policy

      attr_reader :user, :record

      def initialize(user, record)
        @user = user
        @record = record
      end

      subject_screen :users

      def deactivate?
        write? && manage?
      end
    end
  end

  let(:admin_role) { Pundit::Matrix::Role.create!(name: 'Admin', position: 1, admin: true) }
  let(:manager_role) { Pundit::Matrix::Role.create!(name: 'Manager', position: 2) }
  let(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator', position: 3) }

  let(:superadmin) { create_user('super', superadmin: true) }
  let(:admin) { create_user('admin', admin_role) }
  let(:manager) { create_user('manager', manager_role) }
  let(:operator) { create_user('operator', operator_role) }

  before { Pundit::Matrix.screens.draw { screen :users } }

  def create_user(name, *roles, superadmin: false)
    User.create!(email: "#{name}@example.com", superadmin:).tap { |user| user.roles << roles }
  end

  def give(level)
    manager_role.permissions.create!(screen: 'users', level:)
  end

  def allowed(user, record)
    policy = user_policy.new(user, record)
    %i[index? show? new? create? edit? update? destroy? deactivate?].select { |action| policy.public_send(action) }
  end

  it 'lets read list and show the subjects the actor manages' do
    give('read')

    expect(allowed(manager, operator)).to eq(%i[index? show?])
    expect(allowed(manager, admin)).to eq(%i[index?])
  end

  it 'lets write change the subjects the actor manages' do
    give('write')

    expect(allowed(manager, operator)).to eq(%i[index? show? new? create? edit? update? destroy? deactivate?])
    expect(allowed(manager, admin)).to eq(%i[index? new? create?])
  end

  it 'copes with the class instead of a record' do
    give('write')

    expect(allowed(manager, User)).to eq(%i[index? show? new? create? edit? update? destroy? deactivate?])
  end

  it 'allows nothing without a subject' do
    expect(allowed(nil, operator)).to be_empty
  end

  it 'permits roles to whoever may edit, and the flag to a superadmin only' do
    give('write')

    expect(user_policy.new(superadmin, operator).permitted_subject_attributes).to eq([:superadmin, { role_ids: [] }])
    expect(user_policy.new(manager, operator).permitted_subject_attributes).to eq([{ role_ids: [] }])
    expect(user_policy.new(manager, admin).permitted_subject_attributes).to be_empty
  end
end
