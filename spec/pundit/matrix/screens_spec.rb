# frozen_string_literal: true

RSpec.describe Pundit::Matrix::Screens do
  subject(:screens) { described_class.new }

  it 'keeps screens in the order they were declared' do
    screens.draw do
      screen :reservations
      screen :branches
    end

    expect(screens.map(&:key)).to eq(%i[reservations branches])
  end

  it 'puts screens into the group they are declared in' do
    screens.draw do
      group :catalogs do
        screen :branches
      end
      screen :reservations
    end

    expect(screens.fetch(:branches).group).to eq(:catalogs)
    expect(screens.fetch(:reservations).group).to be_nil
  end

  it 'offers none, read and write on a screen' do
    screens.draw { screen :branches }

    expect(screens.fetch(:branches).levels).to eq(%i[none read write])
  end

  it 'offers only none and read on a read-only screen' do
    screens.draw { screen :audit_versions, read_only: true }

    expect(screens.fetch(:audit_versions)).to be_read_only
    expect(screens.fetch(:audit_versions).levels).to eq(%i[none read])
  end

  it 'accepts string keys' do
    screens.draw { screen 'branches' }

    expect(screens.fetch('branches').key).to eq(:branches)
    expect(screens.key?('branches')).to be(true)
  end

  it 'refuses a screen declared twice' do
    expect { screens.draw { 2.times { screen :branches } } }
      .to raise_error(ArgumentError, 'Screen :branches is already declared')
  end

  it 'refuses a group inside a group' do
    expect { screens.draw { group(:a) { group(:b) { screen :branches } } } }
      .to raise_error(ArgumentError, 'Group :a cannot contain another group')
  end

  it 'raises for a screen that is not declared' do
    expect { screens.fetch(:branches) }
      .to raise_error(Pundit::Matrix::UnknownScreenError, 'Screen :branches is not declared')
  end
end
