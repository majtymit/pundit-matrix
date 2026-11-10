require 'generators/pundit/matrix/roles_screen/roles_screen_generator'

RSpec.describe Pundit::Matrix::RolesScreenGenerator do
  let(:root) { Dir.mktmpdir }
  let(:gem_screen) { File.expand_path('../../../../lib/pundit/matrix/active_admin/roles_screen.rb', __dir__) }

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

  it 'copies the roles screen of the gem into the app and turns off the one of the gem' do
    write('config/initializers/pundit_matrix.rb', "Pundit::Matrix.configure do |config|\n  config.screens {}\nend\n")

    output = run_generator

    expect(read('app/admin/roles.rb')).to eq(File.read(gem_screen))
    expect(read('config/initializers/pundit_matrix.rb')).to eq(<<~RUBY)
      Pundit::Matrix.configure do |config|
        # app/admin/roles.rb registers the roles screen.
        config.roles_screen = false

        config.screens {}
      end
    RUBY
    expect(output).not_to include('Set `config.roles_screen = false`')
  end

  it 'turns it off only once' do
    write('config/initializers/pundit_matrix.rb',
          "Pundit::Matrix.configure do |config|\n  config.roles_screen = false\nend\n")

    run_generator

    expect(read('config/initializers/pundit_matrix.rb').scan('roles_screen').size).to eq(1)
  end

  it 'names the setting when it finds no initializer to put it in' do
    output = run_generator

    expect(output).to include('Set `config.roles_screen = false` in config/initializers/pundit_matrix.rb')
  end
end
