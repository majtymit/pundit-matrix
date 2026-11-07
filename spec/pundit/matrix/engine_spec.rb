RSpec.describe Pundit::Matrix::Engine do
  it 'eager loads every file the autoloaders know about' do
    expect { Rails.autoloaders.each(&:eager_load) }.not_to raise_error
  end
end
