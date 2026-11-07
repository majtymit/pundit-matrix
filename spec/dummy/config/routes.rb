Rails.application.routes.draw do
  mount Pundit::Matrix::Engine => '/matrix'
end
