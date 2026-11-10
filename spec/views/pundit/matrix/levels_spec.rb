RSpec.describe 'pundit/matrix/_levels' do
  include_context 'with fresh configuration'

  before do
    Pundit::Matrix.screens.draw do
      group :sales do
        screen :orders
      end
      screen :invoices
    end
  end

  def render_levels(role, **)
    Nokogiri::HTML.fragment(ActionController::Base.render(partial: 'pundit/matrix/levels', locals: { role:, ** }))
  end

  def rows(html)
    html.css('tr').map { |row| row.css('th, td').map { |cell| cell.text.strip } }
  end

  it 'shows the level of every screen, with a dash for no access' do
    role = Pundit::Matrix::Role.create!(name: 'Operator', levels: { orders: 'read' })

    html = render_levels(role)

    expect(rows(html)).to eq([['Sales'], ['Orders', 'Read'], ['General'], ['Invoices', '–']])
    expect(html.css('td[class^="pundit-matrix-"]').map { |cell| cell['class'] })
      .to eq(%w[pundit-matrix-read pundit-matrix-none])
    expect(html.at_css('.pundit-matrix-none span')['title']).to eq('No access')
  end

  it 'marks write apart from read' do
    role = Pundit::Matrix::Role.create!(name: 'Operator', levels: { orders: 'write' })

    expect(render_levels(role).at_css('td.pundit-matrix-write').text.strip).to eq('Write')
  end

  it 'adds the table class of the admin it is in' do
    role = Pundit::Matrix::Role.create!(name: 'Operator')

    expect(render_levels(role, table_class: 'index_table').at_css('table')['class']).to eq('pundit-matrix index_table')
  end

  it 'shows the admin role like any other, with every level it really has' do
    Pundit::Matrix.screens.draw { screen :audit_log, read_only: true }

    rows = rows(render_levels(Pundit::Matrix::Role.admin_role))

    expect(rows).to eq([['Sales'], ['Orders', 'Write'], ['General'], ['Invoices', 'Write'], ['Audit log', 'Read']])
  end

  it 'leaves out the headings when no screen has a group' do
    Pundit::Matrix.instance_variable_set(:@config, Pundit::Matrix::Configuration.new)
    Pundit::Matrix.screens.draw { screen :invoices }

    expect(rows(render_levels(Pundit::Matrix::Role.admin_role))).to eq([%w[Invoices Write]])
  end
end
