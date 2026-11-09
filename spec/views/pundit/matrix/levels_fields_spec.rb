RSpec.describe 'pundit/matrix/_levels_fields' do
  include_context 'with fresh configuration'

  let(:role) { Pundit::Matrix::Role.create!(name: 'Operator', position: 2) }

  before do
    Pundit::Matrix.screens.draw do
      group :sales do
        screen :orders
        screen :audit_log, read_only: true
      end
      screen :invoices
    end
  end

  def render_fields(**locals)
    Nokogiri::HTML.fragment(ActionController::Base.render(partial: 'pundit/matrix/levels_fields', locals:))
  end

  it 'offers every level of every screen, grouped' do
    html = render_fields(role:)

    expect(html.css('tbody th[scope=rowgroup]').map(&:text)).to eq(['Sales'])
    expect(html.css('tbody tr td:first-child').map(&:text)).to eq(['Orders', 'Audit log', 'Invoices'])
    expect(html.css('input[name="role[levels][orders]"]').map { |input| input['value'] })
      .to eq(%w[none read write])
    expect(html.css('input[name="role[levels][audit_log]"]').map { |input| input['value'] })
      .to eq(%w[none read])
  end

  it 'checks the level the role has' do
    role.update!(levels: { orders: 'write' })

    html = render_fields(role:)

    expect(html.at_css('input[name="role[levels][orders]"][checked]')['value']).to eq('write')
    expect(html.at_css('input[name="role[levels][invoices]"][checked]')['value']).to eq('none')
  end

  it 'labels every choice for screen readers' do
    html = render_fields(role:)

    expect(html.at_css('input[name="role[levels][orders]"][value=read]')['aria-label']).to eq('Orders: Read')
  end

  it 'uses the form scope it is given' do
    html = render_fields(role:, scope: 'pundit_matrix_role')

    expect(html.css('input[name="pundit_matrix_role[levels][orders]"]').size).to eq(3)
  end

  it 'takes screen and group labels from the app' do
    I18n.backend.store_translations(
      :en,
      pundit_matrix: {
        screens: { orders: 'Offices' },
        groups: { sales: 'Data' },
      }
    )

    html = render_fields(role:)

    expect(html.css('tbody th, tbody td').map(&:text)).to include('Offices', 'Data')
  ensure
    I18n.reload!
  end

  it 'adds the table class of the admin it is in' do
    expect(render_fields(role:, table_class: 'index_table').at_css('table')['class']).to eq('pundit-matrix index_table')
  end

  it 'explains that an admin role has every permission' do
    admin = Pundit::Matrix::Role.create!(name: 'Admin', position: 1, admin: true)

    expect(render_fields(role: admin).text.strip).to eq(I18n.t('pundit_matrix.admin_role'))
  end
end
