class ApplicationController < ActionController::Base
  include Pundit::Authorization

  def current_user
    User.find_by(id: request.headers['X-User-Id'] || cookies[:user_id])
  end
end
