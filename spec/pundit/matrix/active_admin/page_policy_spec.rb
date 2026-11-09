RSpec.describe Pundit::Matrix::ActiveAdmin::PagePolicy do
  def page(*access)
    ActiveAdmin::Page.new(ActiveAdmin.application.namespace(:admin), 'Page', {}).tap do |page|
      page.matrix_access = access.presence
    end
  end

  it 'lets page actions write with write on the screen of the page' do
    writer = grant_levels(User.create!(email: 'writer@example.com'), widgets: :write)
    reader = grant_levels(User.create!(email: 'reader@example.com'), widgets: :read)

    expect(described_class.new(writer, page(:screen, :widgets))).to be_write
    expect(described_class.new(reader, page(:screen, :widgets))).not_to be_write
    expect(described_class.new(writer, page(:open))).not_to be_write
    expect(described_class.new(nil, page(:screen, :widgets))).not_to be_write
  end

  it 'refuses every page without a subject' do
    expect(described_class.new(nil, page(:open))).not_to be_show
  end

  it 'scopes nothing' do
    expect(described_class::Scope.new(nil, :pages).resolve).to eq(:pages)
  end
end
