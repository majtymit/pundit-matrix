RSpec.shared_context 'with fresh configuration' do
  around do |example|
    original = Pundit::Matrix.config
    Pundit::Matrix.instance_variable_set(:@config, Pundit::Matrix::Configuration.new)
    example.run
  ensure
    Pundit::Matrix.instance_variable_set(:@config, original)
  end
end
