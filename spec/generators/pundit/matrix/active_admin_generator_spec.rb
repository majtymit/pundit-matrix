require 'generators/pundit/matrix/active_admin/active_admin_generator'

RSpec.describe Pundit::Matrix::ActiveAdminGenerator do
  let(:root) { Dir.mktmpdir }

  after { FileUtils.remove_entry(root) }

  def run_generator(*args)
    output = StringIO.new
    original = [$stdout, $stderr]
    $stdout = $stderr = output
    described_class.start(args, destination_root: root)
    output.string
  ensure
    $stdout, $stderr = original
  end

  def read(path)
    File.read(File.join(root, path))
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), content)
  end

  def expect_valid_ruby(source)
    expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
  end

  it 'registers the roles screen in the admin namespace' do
    run_generator

    resource = read('app/admin/roles.rb')
    expect_valid_ruby(resource)
    expect(resource).to include("ActiveAdmin.register Pundit::Matrix::Role, as: 'Role', namespace: :admin do")
    expect(resource).to include("render 'pundit/matrix/superadmin_warning', subjects: User")
  end

  it 'lets the roles screen move roles and keeps their positions out of reach' do
    run_generator

    resource = read('app/admin/roles.rb')
    expect(resource).to include('member_action :move_up, method: :put do', 'member_action :move_down, method: :put do')
    expect(resource).to include('move_up_admin_role_path(role)', 'move_down_admin_role_path(role)')
    expect(resource).to include('f.input :position, input_html: { disabled: true }')
    expect(resource).not_to include('filter :admin', 'column :admin', 'row :admin', 'input :admin')
  end

  it 'creates the role policy and the page policy ActiveAdmin looks for' do
    run_generator

    expect_valid_ruby(read('app/policies/admin/role_policy.rb'))
    expect(read('app/policies/admin/role_policy.rb')).to include('class RolePolicy < Pundit::Matrix::RolePolicy')
    page_policy = read('app/policies/admin/active_admin/page_policy.rb')
    expect_valid_ruby(page_policy)
    expect(page_policy).to include("module Admin\n  module ActiveAdmin\n")
    expect(page_policy).to include('class PagePolicy < Pundit::Matrix::ActiveAdmin::PagePolicy')
  end

  context 'with the files of an ActiveAdmin app' do
    before do
      write('config/initializers/active_admin.rb', "ActiveAdmin.setup do |config|\n  config.site_title = 'App'\nend\n")
      write('app/admin/dashboard.rb', %(ActiveAdmin.register_page "Dashboard" do\n  content {}\nend\n))
      write('app/admin/users.rb', "ActiveAdmin.register User do\n  permit_params :email\nend\n")
    end

    it 'wires the refusals, opens the dashboard and makes the users a subject resource' do
      output = run_generator

      expect(read('config/initializers/active_admin.rb'))
        .to include("ActiveAdmin.setup do |config|\n  config.on_unauthorized_access = :pundit_matrix_access_denied\n")
      expect(read('app/admin/dashboard.rb')).to include(%(register_page "Dashboard" do\n  open_screen\n\n  content))
      expect(read('app/admin/users.rb')).to include("ActiveAdmin.register User do\n  matrix_subject\n\n  permit_params")
      expect(output).not_to include('on_unauthorized_access', 'Add `matrix_subject`', 'in the Dashboard page')
    end

    it 'keeps a refusal handler the app has' do
      write('config/initializers/active_admin.rb',
            "ActiveAdmin.setup do |config|\n  config.on_unauthorized_access = :access_denied\nend\n")

      output = run_generator

      expect(read('config/initializers/active_admin.rb')).not_to include('pundit_matrix_access_denied')
      expect(output).to include('`:pundit_matrix_access_denied`, or keep your own handler')
    end
  end

  it 'names the steps it could not do' do
    output = run_generator

    expect(output).to include('inside `f.inputs`: `f.matrix_subject_inputs`')
    expect(output).to include('Admin::UserPolicy with `subject_screen :users`')
    expect(output).to include('`screen :key`, `admin_screen` or `open_screen`')
    expect(output).to include('Point `config.on_unauthorized_access`')
    expect(output).to include('Declare `open_screen` in the Dashboard page')
    expect(output).to include('Add `matrix_subject` to `ActiveAdmin.register User`')
  end

  it 'turns the screen of the namespaced subject policy into a subject screen' do
    write('app/policies/admin/user_policy.rb', <<~RUBY)
      module Admin
        class UserPolicy < DefaultPolicy
          screen :users
        end
      end
    RUBY

    output = run_generator

    expect(read('app/policies/admin/user_policy.rb')).to include("    subject_screen :users\n")
    expect(output).not_to include('Admin::UserPolicy with')
  end

  it 'declares the subject screen in a namespaced subject policy without one' do
    write('app/policies/admin/user_policy.rb', "module Admin\n  class UserPolicy < DefaultPolicy\n  end\nend\n")

    run_generator

    expect(read('app/policies/admin/user_policy.rb'))
      .to eq("module Admin\n  class UserPolicy < DefaultPolicy\n    subject_screen :users\n\n  end\nend\n")
  end

  describe 'a page policy the app has already' do
    before do
      write('app/policies/admin/active_admin/page_policy.rb', <<~RUBY)
        module Admin
          module ActiveAdmin
            class PagePolicy
            end
          end
        end
      RUBY
    end

    it 'says where its logic belongs once replaced' do
      output = run_generator('--force')

      expect(read('app/policies/admin/active_admin/page_policy.rb'))
        .to include('Pundit::Matrix::ActiveAdmin::PagePolicy')
      expect(output).to include('page_policy.rb was replaced; what it decided now belongs in each `register_page`')
    end

    it 'says what it needs when kept' do
      output = run_generator('--skip')

      expect(read('app/policies/admin/active_admin/page_policy.rb')).not_to include('Pundit::Matrix')
      expect(output).to include('page_policy.rb was kept; inherit it from Pundit::Matrix::ActiveAdmin::PagePolicy')
    end
  end

  it 'takes another namespace and subject' do
    output = run_generator('Account', '--namespace=backoffice')

    expect(read('app/admin/roles.rb')).to include('namespace: :backoffice do')
    expect(read('app/admin/roles.rb')).to include('subjects: Account')
    expect(read('app/policies/backoffice/role_policy.rb')).to include("module Backoffice\n")
    expect(read('app/policies/backoffice/active_admin/page_policy.rb')).to include("module Backoffice\n")
    expect(output).to include('Backoffice::AccountPolicy')
  end

  describe 'the screens spec' do
    it 'is written only for an app with specs' do
      run_generator

      expect(File.exist?(File.join(root, 'spec/requests/admin/pundit_matrix_screens_spec.rb'))).to be(false)
    end

    it 'signs in through Devise and builds the subject with FactoryBot' do
      stub_const('Devise', Module.new)
      FileUtils.mkdir_p(File.join(root, 'spec/factories'))

      output = run_generator

      spec = read('spec/requests/admin/pundit_matrix_screens_spec.rb')
      expect_valid_ruby(spec)
      expect(spec).to include('include Devise::Test::IntegrationHelpers')
      expect(spec).to include('create(:user)')
      expect(spec).to include('ActiveAdmin.application.namespaces[:admin]')
      expect(spec).to include('expect(screen_map.conflicts).to be_empty')
      expect(spec).to include('ScreenMap.new(namespace, except: outside_the_matrix)')
      expect(spec).to include('expect(screen_map.level_mismatches(create_subject)).to be_empty')
      expect(spec).not_to include('NotImplementedError')
      expect(output).not_to include('Adjust `create_subject`')
    end

    it 'builds a Devise subject without FactoryBot' do
      stub_const('Devise', Module.new)
      FileUtils.mkdir_p(File.join(root, 'spec'))

      run_generator

      expect(read('spec/requests/admin/pundit_matrix_screens_spec.rb')).to include('password: SecureRandom.base58(24)')
    end

    it 'leaves the sign in to the app without Devise' do
      FileUtils.mkdir_p(File.join(root, 'spec'))

      output = run_generator

      spec = read('spec/requests/admin/pundit_matrix_screens_spec.rb')
      expect_valid_ruby(spec)
      expect(spec).to include("raise NotImplementedError, 'Sign the subject in the way your app does'")
      expect(spec).to match(/User\.create!\(email: "subject-.+@example\.test"\)$/)
      expect(output).to include('Adjust `create_subject` and `sign_in`')
    end
  end
end
