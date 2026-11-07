RSpec.describe Pundit::Matrix do
  it 'has a version number' do
    expect(Pundit::Matrix::VERSION).not_to be_nil
  end

  describe '.configure' do
    include_context 'with fresh configuration'

    it 'uses User as the subject class and no table prefix by default' do
      expect(described_class.config).to have_attributes(subject_class: 'User', table_prefix: '')
    end

    it 'changes the configuration' do
      described_class.configure do |config|
        config.subject_class = 'Account'
        config.table_prefix = 'matrix_'
      end

      expect(described_class.config).to have_attributes(subject_class: 'Account', table_prefix: 'matrix_')
    end

    it "gives the gem's tables the configured prefix" do
      described_class.configure { |config| config.table_prefix = 'matrix_' }

      expect(described_class.table_name_prefix).to eq('matrix_')
    end

    it 'declares screens' do
      described_class.configure do |config|
        config.screens do
          screen :branches
        end
      end

      expect(described_class.screens.map(&:key)).to eq([:branches])
    end
  end
end
