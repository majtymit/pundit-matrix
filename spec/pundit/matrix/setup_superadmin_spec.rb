require 'rake'

RSpec.describe Pundit::Matrix, '.setup_superadmin!' do
  let(:user) { User.create!(email: 'a@example.com') }

  it 'creates the admin role and makes the subject a superadmin holding it' do
    role = described_class.setup_superadmin!(user)

    expect(role).to have_attributes(name: 'Admin', position: 1, admin: true)
    expect(user.reload).to be_superadmin
    expect(user.roles).to eq([role])
  end

  it 'reuses the highest admin role and keeps the other roles' do
    admin_role = Pundit::Matrix::Role.create!(name: 'Správca', position: 2, admin: true)
    operator = Pundit::Matrix::Role.create!(name: 'Operator', position: 3)
    user.roles << operator

    described_class.setup_superadmin!(user)
    described_class.setup_superadmin!(user)

    expect(Pundit::Matrix::Role.admins).to eq([admin_role])
    expect(user.reload.roles).to contain_exactly(admin_role, operator)
  end

  it 'runs whoever acts' do
    other = User.create!(email: 'b@example.com')

    Pundit::Matrix::Current.set(actor: other) { described_class.setup_superadmin!(user) }

    expect(user.reload).to be_superadmin
  end

  describe 'the rake task' do
    before { Rails.application.load_tasks unless Rake::Task.task_defined?('pundit_matrix:superadmin') }

    def run_task(**env)
      output = StringIO.new
      original = [$stdout, ENV.to_h]
      $stdout = output
      env.each { |name, value| ENV[name.to_s] = value }
      Rake::Task['pundit_matrix:superadmin'].execute
      output.string
    ensure
      $stdout = original.first
      ENV.replace(original.last)
    end

    it 'sets up the subject with the email' do
      output = run_task(EMAIL: user.email)

      expect(output).to eq("a@example.com is a superadmin with the Admin role\n")
      expect(user.reload).to be_superadmin
    end

    it 'takes another subject model' do
      account = Class.new(ApplicationRecord) do
        self.table_name = 'users'
        has_roles
      end
      stub_const('Account', account)
      allow(described_class).to receive(:setup_superadmin!).and_call_original

      run_task(EMAIL: user.email, MODEL: 'Account')

      expect(described_class).to have_received(:setup_superadmin!).with(Account.find(user.id))
    end

    it 'asks for the email' do
      expect { run_task(EMAIL: nil) }
        .to raise_error(SystemExit)
        .and output("Usage: bin/rails pundit_matrix:superadmin EMAIL=someone@example.com\n").to_stderr
    end

    it 'says plainly that nobody has the email' do
      expect { run_task(EMAIL: 'nobody@example.com') }
        .to raise_error(SystemExit) { |exit| expect(exit.status).to eq(1) }
        .and output("No User with email nobody@example.com\n").to_stderr
    end

    it 'says plainly that the model does not exist' do
      expect { run_task(EMAIL: user.email, MODEL: 'Nobody') }
        .to raise_error(SystemExit, 'No model Nobody')
        .and output("No model Nobody\n").to_stderr
    end
  end
end
