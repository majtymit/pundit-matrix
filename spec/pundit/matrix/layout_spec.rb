RSpec.describe Pundit::Matrix::Layout do
  include_context 'with fresh configuration'

  before do
    Pundit::Matrix.screens.draw do
      screen :orders
      screen :invoices
      screen :users
      screen :audit_log, read_only: true
    end
  end

  def place(priority:, group: nil, group_priority: nil, label: nil)
    described_class::Place.new(group:, group_label: group&.to_s&.upcase, group_priority:, priority:, label:)
  end

  def shown(places = {})
    described_class.new(places).groups.map { |group| [group.label, group.rows.map(&:label)] }
  end

  it 'keeps the declared order and no heading when no screen has a group' do
    expect(shown).to eq([[nil, ['Orders', 'Invoices', 'Users', 'Audit log']]])
  end

  it 'takes groups, their order, the order of their screens and the labels from the places of the menu' do
    places = {
      orders: place(group: :sales, group_priority: 2, priority: 2, label: 'Orders'),
      invoices: place(group: :sales, group_priority: 2, priority: 1, label: 'Bills'),
      users: place(group: :access, group_priority: 1, priority: 1, label: 'People'),
      audit_log: place(priority: 3, label: 'Audit'),
    }

    expect(shown(places)).to eq([['ACCESS', ['People']], ['SALES', %w[Bills Orders]], ['General', ['Audit']]])
  end

  it 'puts the ungrouped screens among the groups by the menu priority of their items' do
    places = { orders: place(group: :sales, group_priority: 4, priority: 1), audit_log: place(priority: 2) }

    expect(shown(places).map(&:first)).to eq(%w[General SALES])
    expect(shown(places).first.last).to eq(['Audit log', 'Invoices', 'Users'])
  end

  it 'lets the initializer and the translations win over the menu' do
    Pundit::Matrix.instance_variable_set(:@config, Pundit::Matrix::Configuration.new)
    Pundit::Matrix.screens.draw do
      group(:billing) { screen :invoices }
      screen :orders
    end
    translations = { screens: { orders: 'Purchases' }, groups: { sales: 'Selling' } }
    I18n.backend.store_translations(:en, pundit_matrix: translations)
    places = {
      invoices: place(group: :sales, group_priority: 1, priority: 1, label: 'Bills'),
      orders: place(group: :sales, group_priority: 1, priority: 1, label: 'Orders'),
    }

    expect(shown(places)).to eq([['Selling', ['Purchases']], ['Billing', ['Bills']]])
  ensure
    I18n.backend.reload!
  end
end
