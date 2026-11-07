# frozen_string_literal: true

RSpec.describe Pundit::Matrix do
  it "has a version number" do
    expect(Pundit::Matrix::VERSION).not_to be nil
  end

  describe ".configure" do
    around do |example|
      original = described_class.config.dup
      example.run
      described_class.instance_variable_set(:@config, original)
    end

    it "uses User as the subject class and no table prefix by default" do
      expect(described_class.config).to have_attributes(subject_class: "User", table_prefix: "")
    end

    it "changes the configuration" do
      described_class.configure do |config|
        config.subject_class = "Account"
        config.table_prefix = "matrix_"
      end

      expect(described_class.config).to have_attributes(subject_class: "Account", table_prefix: "matrix_")
    end

    it "gives the gem's tables the configured prefix" do
      described_class.configure { |config| config.table_prefix = "matrix_" }

      expect(described_class.table_name_prefix).to eq("matrix_")
    end
  end
end
