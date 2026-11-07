# frozen_string_literal: true

module Pundit
  module Matrix
    class Engine < ::Rails::Engine
      isolate_namespace Pundit::Matrix
    end
  end
end
