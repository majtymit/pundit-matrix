module Admin
  class UserPolicy < ApplicationPolicy
    subject_screen :users
  end
end
