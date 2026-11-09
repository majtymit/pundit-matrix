namespace :pundit_matrix do
  desc 'Make the subject with EMAIL (of MODEL, User by default) a superadmin holding the admin role'
  task superadmin: :environment do
    email = ENV.fetch('EMAIL') { abort 'Usage: bin/rails pundit_matrix:superadmin EMAIL=someone@example.com' }
    model = ENV.fetch('MODEL', 'User')
    subjects = model.safe_constantize or abort "No model #{model}"
    subject = subjects.find_by(email:) or abort "No #{model} with email #{email}"
    role = Pundit::Matrix.setup_superadmin!(subject)

    puts "#{email} is a superadmin with the #{role.name} role"
  end
end
