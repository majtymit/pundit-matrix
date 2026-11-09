require 'generators/pundit/matrix/install/install_generator'

RSpec.describe Pundit::Matrix::InstallGenerator do
  let(:root) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(root, 'app/models'))
    File.write(File.join(root, 'app/models/user.rb'), "class User < ApplicationRecord\nend\n")
  end

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

  def next_steps(output)
    output[/^Next:\n(.*)/m, 1].lines.map { |line| line.sub(/^\s+\d+\. /, '').strip }
  end

  def migration
    read(Dir.glob('db/migrate/*_create_pundit_matrix_tables.rb', base: root).first)
  end

  it 'installs the gem with a table prefix' do
    output = run_generator('User', '--table-prefix=matrix_')

    expect(migration).to include('create_table :matrix_roles do |t|')
    expect(migration).to include("ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]")
    expect(read('config/initializers/pundit_matrix.rb')).to include("config.table_prefix = 'matrix_'")
    expect(read('app/models/user.rb')).to eq("class User < ApplicationRecord\n  has_roles\nend\n")
    expect(output.scan('Next:').size).to eq(1)
  end

  describe 'with ActiveAdmin' do
    it 'sets it up and leaves out the role policy outside the namespace, which nothing would use' do
      run_generator('User', '--table-prefix=matrix_')

      expect(File.exist?(File.join(root, 'app/admin/roles.rb'))).to be(true)
      expect(File.exist?(File.join(root, 'app/policies/role_policy.rb'))).to be(false)
    end

    it 'prints one list, in the order the steps are done' do
      output = run_generator('User', '--table-prefix=matrix_')

      steps = next_steps(output)
      expect(steps.first).to eq('Run the migrations.')
      expect(steps.index { |step| step.include?('subject_fields') })
        .to be_between(steps.index { |step| step.include?('screen :key') }, steps.size - 2)
      expect(steps.last).to eq('Make someone a superadmin: bin/rails pundit_matrix:superadmin EMAIL=you@example.com')
    end
  end

  describe 'without ActiveAdmin' do
    before { hide_const('ActiveAdmin') }

    it 'creates the role policy Pundit finds for roles' do
      run_generator('User', '--table-prefix=matrix_')

      expect(File.exist?(File.join(root, 'app/admin/roles.rb'))).to be(false)
      expect(read('app/policies/role_policy.rb')).to include('class RolePolicy < Pundit::Matrix::RolePolicy')
    end

    it 'turns the screen of the subject policy into a subject screen' do
      write('app/policies/user_policy.rb', "class UserPolicy < ApplicationPolicy\n  screen :accounts\nend\n")

      output = run_generator('User', '--table-prefix=matrix_')

      expect(read('app/policies/user_policy.rb')).to include("  subject_screen :accounts\n")
      expect(output).not_to include('Declare the screen in UserPolicy')
    end

    it 'declares the subject screen in a subject policy without a screen' do
      write('app/policies/user_policy.rb', <<~RUBY)
        class UserPolicy < ApplicationPolicy
          def destroy?
            false
          end
        end
      RUBY

      run_generator('User', '--table-prefix=matrix_')

      expect(read('app/policies/user_policy.rb'))
        .to start_with("class UserPolicy < ApplicationPolicy\n  subject_screen :users\n\n  def destroy?")
    end

    it 'leaves a subject screen as it is' do
      content = "class UserPolicy < ApplicationPolicy\n  subject_screen :people\nend\n"
      write('app/policies/user_policy.rb', content)

      run_generator('User', '--table-prefix=matrix_')

      expect(read('app/policies/user_policy.rb')).to eq(content)
    end

    it 'lists the subject policy it could not find' do
      output = run_generator('User', '--table-prefix=matrix_')

      expect(next_steps(output)).to include('Declare the screen in UserPolicy with `subject_screen :users`.')
    end

    it 'lists a subject policy it cannot read' do
      write('app/policies/user_policy.rb', "UserPolicy = Class.new(ApplicationPolicy)\n")

      output = run_generator('User', '--table-prefix=matrix_')

      expect(next_steps(output)).to include('Declare the screen in UserPolicy with `subject_screen :users`.')
    end
  end

  describe 'the base policy' do
    it 'extends an existing one' do
      write('app/policies/application_policy.rb', "class ApplicationPolicy\n  attr_reader :user\nend\n")

      output = run_generator('User', '--table-prefix=matrix_')

      expect(read('app/policies/application_policy.rb'))
        .to eq("class ApplicationPolicy\n  extend Pundit::Matrix::Policy\n\n  attr_reader :user\nend\n")
      expect(output).not_to include('Create app/policies/application_policy.rb')
    end

    it 'leaves one that extends it already' do
      content = "class ApplicationPolicy\n  extend Pundit::Matrix::Policy\nend\n"
      write('app/policies/application_policy.rb', content)

      run_generator('User', '--table-prefix=matrix_')

      expect(read('app/policies/application_policy.rb')).to eq(content)
    end

    it 'lists it when the app has none' do
      output = run_generator('User', '--table-prefix=matrix_')

      expect(next_steps(output))
        .to include('Create app/policies/application_policy.rb with `extend Pundit::Matrix::Policy`.')
    end
  end

  describe 'has_roles' do
    it 'goes below the comment that describes the class' do
      write('app/models/user.rb', <<~RUBY)
        class User < ApplicationRecord
          # Someone who signs in.
          # Never deleted.

          validates :email
        end
      RUBY

      run_generator('User', '--table-prefix=matrix_')

      expect(read('app/models/user.rb')).to eq(<<~RUBY)
        class User < ApplicationRecord
          # Someone who signs in.
          # Never deleted.
          has_roles

          validates :email
        end
      RUBY
    end

    it 'goes after the last include or extend' do
      write('app/models/user.rb', <<~RUBY)
        class User < ApplicationRecord
          # Someone.
          include Auditable
          extend Searchable

          devise :database_authenticatable
        end
      RUBY

      run_generator('User', '--table-prefix=matrix_')

      expect(read('app/models/user.rb')).to include("  extend Searchable\n\n  has_roles\n\n  devise")
    end

    it 'is not added twice' do
      write('app/models/user.rb', "class User < ApplicationRecord\n  has_roles\nend\n")

      run_generator('User', '--table-prefix=matrix_')

      expect(read('app/models/user.rb')).to eq("class User < ApplicationRecord\n  has_roles\nend\n")
    end
  end

  it 'leaves the superadmin column alone when the subject answers superadmin? already' do
    run_generator('User', '--table-prefix=matrix_')

    expect(Dir.glob('db/migrate/*_add_superadmin_*.rb', base: root)).to be_empty
  end

  it 'uses the primary key type of the app and of the subject' do
    allow(Rails.application.config.generators).to receive(:options)
      .and_return(active_record: { primary_key_type: :uuid })
    uuid = instance_double(ActiveRecord::ConnectionAdapters::Column, type: :uuid)
    allow(User).to receive(:columns_hash).and_return('id' => uuid)

    run_generator('User', '--table-prefix=matrix_')

    expect(migration).to include('create_table :matrix_roles, id: :uuid do |t|')
    expect(migration).to include("polymorphic: true,\n                   index: false,\n                   type: :uuid")
  end

  it 'leaves out the table prefix when there is none' do
    allow(ActiveRecord::Base.connection).to receive(:table_exists?).and_return(false)

    run_generator

    expect(migration).to include('create_table :roles do |t|')
    expect(read('config/initializers/pundit_matrix.rb')).not_to include('table_prefix')
  end

  it 'refuses tables that already exist' do
    output = run_generator('User')

    expect(output).to include('Tables roles, permissions, role_assignments already exist')
    expect(Dir.exist?(File.join(root, 'db'))).to be(false)
  end

  it 'refuses a model that does not exist' do
    expect(run_generator('Account')).to include('Model Account does not exist')
  end

  it 'adds the superadmin column to a subject that does not answer superadmin?' do
    stub_const('Account', Class.new(ApplicationRecord) { self.table_name = 'roles' })
    File.write(File.join(root, 'app/models/account.rb'), "class Account < ApplicationRecord\nend\n")

    run_generator('Account', '--table-prefix=matrix_')

    migration = read(Dir.glob('db/migrate/*_add_superadmin_to_roles.rb', base: root).first)
    expect(migration).to include('class AddSuperadminToRoles < ActiveRecord::Migration[')
    expect(migration).to include('add_column :roles, :superadmin, :boolean, null: false, default: false')
  end
end
