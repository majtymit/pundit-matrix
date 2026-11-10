ActiveAdmin.register_page 'Dashboard' do
  open_screen

  content { para 'Dashboard' }
end

ActiveAdmin.register_page 'Reports' do
  screen :reports
  menu priority: 1

  content { para 'Reports' }
end

ActiveAdmin.register_page 'Audit' do
  admin_screen

  content { para 'Audit' }
end

ActiveAdmin.register_page 'Forgotten' do
  content { para 'Forgotten' }
end
