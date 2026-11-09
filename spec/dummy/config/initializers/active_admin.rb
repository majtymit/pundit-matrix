require 'erb'

generated = Dir.mktmpdir('pundit-matrix-generated')
templates = File.expand_path('../../../../lib/generators/pundit/matrix/active_admin/templates', __dir__)
{
  'roles.rb.tt' => 'admin/roles.rb',
  'role_policy.rb.tt' => 'policies/role_policy.rb',
  'page_policy.rb.tt' => 'policies/page_policy.rb',
}.each do |template, path|
  file = File.join(generated, path)
  FileUtils.mkdir_p(File.dirname(file))
  source = ERB.new(File.read(File.join(templates, template)), trim_mode: '-')
  File.write(file, source.result_with_hash(namespace: 'admin', subject_name: 'User'))
end
Rails.application.config.to_prepare do
  Dir[File.join(generated, 'policies/*.rb')].each { |file| load file }
end

ActiveAdmin.setup do |config|
  config.load_paths = [Rails.root.join('app/admin').to_s, File.join(generated, 'admin')]
  config.authentication_method = false
  config.logout_link_path = false
  config.current_user_method = :current_user
  config.authorization_adapter = ActiveAdmin::PunditAdapter
  config.pundit_policy_namespace = :admin
  config.comments = false
  config.batch_actions = false
  config.on_unauthorized_access = :pundit_matrix_access_denied
end
