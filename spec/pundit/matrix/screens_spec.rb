RSpec.describe Pundit::Matrix::Screens do
  subject(:screens) { described_class.new }

  it 'keeps screens in the order they were declared' do
    screens.draw do
      screen :invoices
      screen :orders
    end

    expect(screens.map(&:key)).to eq(%i[invoices orders])
  end

  it 'puts screens into the group they are declared in' do
    screens.draw do
      group :sales do
        screen :orders
      end
      screen :invoices
    end

    expect(screens.fetch(:orders).group).to eq(:sales)
    expect(screens.fetch(:invoices).group).to be_nil
  end

  it 'offers none, read and write on a screen' do
    screens.draw { screen :orders }

    expect(screens.fetch(:orders).levels).to eq(%i[none read write])
  end

  it 'offers only none and read on a read-only screen' do
    screens.draw { screen :audit_log, read_only: true }

    expect(screens.fetch(:audit_log)).to be_read_only
    expect(screens.fetch(:audit_log).levels).to eq(%i[none read])
  end

  it 'accepts string keys' do
    screens.draw { screen 'orders' }

    expect(screens.fetch('orders').key).to eq(:orders)
    expect(screens.key?('orders')).to be(true)
  end

  it 'refuses a screen declared twice' do
    expect { screens.draw { 2.times { screen :orders } } }
      .to raise_error(ArgumentError, 'Screen :orders is already declared')
  end

  it 'refuses a group inside a group' do
    expect { screens.draw { group(:a) { group(:b) { screen :orders } } } }
      .to raise_error(ArgumentError, 'Group :a cannot contain another group')
  end

  it 'raises for a screen that is not declared' do
    expect { screens.fetch(:orders) }
      .to raise_error(Pundit::Matrix::UnknownScreenError, 'Screen :orders is not declared')
  end
end
