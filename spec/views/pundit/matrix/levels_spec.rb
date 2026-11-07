RSpec.describe 'pundit/matrix/_levels' do
  include_context 'with fresh configuration'

  before do
    Pundit::Matrix.screens.draw do
      group :catalogs do
        screen :branches
      end
      screen :reservations
    end
  end

  def render_levels(role, **)
    Nokogiri::HTML.fragment(ActionController::Base.render(partial: 'pundit/matrix/levels', locals: { role:, ** }))
  end

  it 'shows the level of every screen' do
    role = Pundit::Matrix::Role.create!(name: 'Operator', position: 2, levels: { branches: 'read' })

    rows = render_levels(role).css('tr').map { |row| row.css('th, td').map(&:text) }

    expect(rows).to eq([['Catalogs'], ['Branches', 'Read'], ['Reservations', 'No access']])
  end

  it 'adds the table class of the admin it is in' do
    role = Pundit::Matrix::Role.create!(name: 'Operator', position: 2)

    expect(render_levels(role, table_class: 'index_table').at_css('table')['class']).to eq('pundit-matrix index_table')
  end

  it 'explains that an admin role has every permission' do
    admin = Pundit::Matrix::Role.create!(name: 'Admin', position: 1, admin: true)

    expect(render_levels(admin).text.strip).to eq(I18n.t('pundit_matrix.admin_role'))
  end
end
