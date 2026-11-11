RSpec.describe Pundit::Matrix::Lint do
  include_context 'with fresh configuration'

  let(:base) { Class.new { extend Pundit::Matrix::Policy } }

  before do
    Pundit::Matrix.screens.draw do
      screen :orders
      screen :users
      screen :reports
    end
    stub_const('LintBasePolicy', base)
    stub_const('OrderPolicy', Class.new(base) { screen :orders })
    stub_const('UserPolicy', Class.new(base) { subject_screen :users })
    stub_const('Admin::OrderPolicy', Class.new(OrderPolicy))
    stub_const('DefaultPolicy', Class.new(base))
    stub_const('DashboardPolicy', Class.new(base))
    stub_const('VersionPolicy', Class.new(base) { admin_screen })
    stub_const('AccountPolicy', Class.new(base) { admin_subject_screen })
    Class.new(base)
  end

  it 'finds policies that declare no screen' do
    expect(described_class.policies_without_screen(base)).to eq([DashboardPolicy, DefaultPolicy])
    expect(described_class.policies_without_screen(base, except: [DefaultPolicy])).to eq([DashboardPolicy])
  end

  it 'finds screens no policy uses' do
    expect(described_class.unused_screens(base)).to eq([:reports])
  end
end
