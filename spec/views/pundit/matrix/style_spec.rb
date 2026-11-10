RSpec.describe 'pundit/matrix/_style' do
  include_context 'with fresh configuration'

  let(:role) { Pundit::Matrix::Role.create!(name: 'Operator') }

  before { Pundit::Matrix.screens.draw { group(:sales) { screen :orders } } }

  def render_partial(partial, renderer: ActionController::Base.renderer)
    Nokogiri::HTML.fragment(renderer.render(partial: "pundit/matrix/#{partial}", locals: { role: }))
  end

  it 'comes with the matrix in the form and on the detail' do
    %w[levels levels_fields].each do |partial|
      style = render_partial(partial).at_css('style').text

      expect(style.scan(/([^{}]+)\{/).flatten.map(&:strip)).to all(start_with('.pundit-matrix')), partial
      expect(style).to match(/\.pundit-matrix th\[scope="rowgroup"\] \{\s+padding-top: 1\.75em; text-align: left;/)
    end
  end

  it 'draws row lines in the form only, as the attributes table of the detail draws its own' do
    style = render_partial('levels').at_css('style').text
    lined = style.scan(/([^{}]+)\{[^{}]*border-bottom/).flatten.join.split(',').map(&:strip)

    expect(lined).to eq(['.pundit-matrix-levels .pundit-matrix thead th', '.pundit-matrix-levels .pundit-matrix td'])
  end

  it 'lines the form matrix up with the text inputs and gives each level a fixed share' do
    style = render_partial('levels_fields').at_css('style').text

    expect(style).to include('.pundit-matrix-levels .pundit-matrix { width: calc(80% - 22px); }')
    expect(style).to include('.pundit-matrix .pundit-matrix-level { width: 20%; text-align: center; }')
  end

  it 'centres the levels of the form' do
    html = render_partial('levels_fields')

    expect(html.css('thead th.pundit-matrix-level').size).to eq(3)
    expect(html.css('tbody td.pundit-matrix-level').size).to eq(3)
  end

  it 'takes the nonce of the content security policy' do
    renderer = ActionController::Base.renderer.new(
      'action_dispatch.content_security_policy_nonce_generator' => ->(_request) { 'n0nce' }
    )

    expect(render_partial('levels', renderer:).at_css('style')['nonce']).to eq('n0nce')
    expect(render_partial('levels').at_css('style')['nonce']).to be_nil
  end
end
