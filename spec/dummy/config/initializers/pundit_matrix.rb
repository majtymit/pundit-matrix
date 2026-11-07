Pundit::Matrix.configure do |config|
  config.active_superadmins = -> { where(superadmin: true, deactivated_at: nil) }
end
