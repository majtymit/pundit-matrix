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

      expect(style.scan(/^\s*(\S[^{]*?)\s*\{/).flatten).to all(start_with('.pundit-matrix')), partial
      expect(style).to include('.pundit-matrix th[scope="rowgroup"] { padding-top: 1.75em; text-align: left;')
      expect(style).to include('border-bottom: 1px solid')
    end
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
