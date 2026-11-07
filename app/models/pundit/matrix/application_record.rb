# frozen_string_literal: true

module Pundit
  module Matrix
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
