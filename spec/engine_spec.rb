# frozen_string_literal: true

RSpec.describe Pundit::Matrix::Engine do
  it "is mounted in the host app" do
    mounted = Rails.application.routes.routes.map(&:app).map { |app| app.try(:app) }

    expect(mounted).to include(described_class)
  end
end
