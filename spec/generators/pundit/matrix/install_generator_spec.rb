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

  def migration
    read(Dir.glob('db/migrate/*_create_pundit_matrix_tables.rb', base: root).first)
  end

  it 'installs the gem with a table prefix' do
    output = run_generator('User', '--table-prefix=matrix_')

    expect(migration).to include('create_table :matrix_roles do |t|')
    expect(migration).to include("ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]")
    expect(read('config/initializers/pundit_matrix.rb')).to include("config.table_prefix = 'matrix_'")
    expect(read('app/models/user.rb')).to eq("class User < ApplicationRecord\n  has_roles\nend\n")
    expect(output).to include('Make someone a superadmin')
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

  it 'refuses a model that does not answer superadmin?' do
    stub_const('Account', Class.new(ApplicationRecord) { self.table_name = 'roles' })

    expect(run_generator('Account')).to include('Account must answer superadmin?')
  end
end
