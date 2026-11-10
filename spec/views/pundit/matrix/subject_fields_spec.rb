RSpec.describe 'pundit/matrix/_subject_fields' do
  let(:admin_role) { Pundit::Matrix::Role.admin_role }
  let(:manager_role) { Pundit::Matrix::Role.create!(name: 'Manager') }
  let(:operator_role) { Pundit::Matrix::Role.create!(name: 'Operator') }

  let(:superadmin) { make_superadmin(User.create!(email: 'super@example.com')) }
  let(:manager) { User.create!(email: 'manager@example.com').tap { |user| user.roles << manager_role } }
  let(:subject_user) { User.create!(email: 'a@example.com').tap { |user| user.roles << operator_role } }

  before { [admin_role, manager_role, operator_role] }

  def render_fields(actor, **locals)
    locals = { subject: subject_user, **locals }
    html = Pundit::Matrix::Current.set(actor:) do
      ActionController::Base.render(partial: 'pundit/matrix/subject_fields', locals:)
    end
    Nokogiri::HTML.fragment(html)
  end

  def role_boxes(html)
    html.css('input[type=checkbox][name="user[role_ids][]"]')
  end

  it 'offers every role in order and checks the held ones' do
    html = render_fields(superadmin)

    expect(html.css('label').map { |label| label.text.strip }).to start_with('Admin', 'Manager', 'Operator')
    expect(role_boxes(html).map { |box| box['value'] })
      .to eq([admin_role, manager_role, operator_role].map { |role| role.id.to_s })
    expect(role_boxes(html).select { |box| box['checked'] }.map { |box| box['value'] }).to eq([operator_role.id.to_s])
  end

  it 'disables the roles the actor cannot assign' do
    subject_user.roles << admin_role

    boxes = role_boxes(render_fields(manager))

    expect(boxes.reject { |box| box['disabled'] }.map { |box| box['value'] }).to eq([operator_role.id.to_s])
    expect(boxes.find { |box| box['value'] == admin_role.id.to_s }['checked']).to eq('checked')
  end

  it 'sends an empty value so that unchecking every role works' do
    hidden = render_fields(manager).css('input[type=hidden][name="user[role_ids][]"]')

    expect(hidden.map { |input| input['value'] }).to eq([''])
  end

  it 'shows the superadmin checkbox only to a superadmin' do
    expect(render_fields(superadmin).css('input[name="user[superadmin]"]').map { |input| input['value'] })
      .to eq(%w[0 1])
    expect(render_fields(manager).css('input[name="user[superadmin]"]')).to be_empty
    expect(render_fields(nil).css('input[name="user[superadmin]"]')).to be_empty
  end

  it 'restricts no role without an actor' do
    expect(role_boxes(render_fields(nil)).select { |box| box['disabled'] }).to be_empty
  end

  it 'uses the form scope it is given' do
    expect(render_fields(manager, scope: 'account').css('input[name="account[role_ids][]"]').size).to eq(4)
  end
end
