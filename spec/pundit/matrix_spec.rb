RSpec.describe Pundit::Matrix do
  it 'has a version number' do
    expect(Pundit::Matrix::VERSION).not_to be_nil
  end

  describe '.configure' do
    include_context 'with fresh configuration'

    it 'uses no table prefix by default' do
      expect(described_class.table_name_prefix).to eq('')
    end

    it "gives the gem's tables the configured prefix" do
      described_class.configure { |config| config.table_prefix = 'matrix_' }

      expect(described_class.table_name_prefix).to eq('matrix_')
    end

    it 'declares screens' do
      described_class.configure do |config|
        config.screens do
          screen :orders
        end
      end

      expect(described_class.screens.map(&:key)).to eq([:orders])
    end
  end

  describe '.t' do
    after { I18n.reload! }

    it 'translates with the app translation of the current locale' do
      I18n.backend.store_translations(:sk, pundit_matrix: { levels: { read: 'Čítanie' } })

      I18n.with_locale(:sk) { expect(described_class.t('levels.read')).to eq('Čítanie') }
    end

    it "falls back to the gem's English when the current locale has no translation" do
      I18n.with_locale(:sk) { expect(described_class.t('levels.read')).to eq('Read') }
    end
  end
end
