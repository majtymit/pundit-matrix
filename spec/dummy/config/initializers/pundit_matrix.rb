Pundit::Matrix.configure do |config|
  config.screens do
    screen :users
    screen :widgets
    screen :reports, read_only: true
  end
end
