class User < ApplicationRecord
  include Pundit::Matrix::Subject
end
