RSpec.describe 'pundit/matrix/_superadmin_warning' do
  def render_warning
    ActionController::Base.render(partial: 'pundit/matrix/superadmin_warning', locals: { subjects: User }).strip
  end

  it 'warns while nobody is an active superadmin' do
    User.create!(email: 'former@example.com', superadmin: true, deactivated_at: Time.current)

    expect(render_warning).to include(I18n.t('pundit_matrix.no_superadmin'))
  end

  it 'shows nothing once an active superadmin exists' do
    User.create!(email: 'super@example.com', superadmin: true)

    expect(render_warning).to be_empty
  end
end
