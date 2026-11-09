module Pundit
  module Matrix
    module ActiveAdmin
      class PagePolicy
        attr_reader :user, :record

        def initialize(user, record)
          @user = user
          @record = record
        end

        def show?
          kind, key = record.matrix_access
          return false if user.nil?

          case kind
          when :open then true
          when :admin then user.access.everything?
          when :screen then user.access.read?(key)
          else false
          end
        end

        def write?
          kind, key = record.matrix_access
          kind == :screen && user.present? && user.access.write?(key)
        end

        class Scope
          def initialize(user, scope)
            @user = user
            @scope = scope
          end

          def resolve
            @scope
          end
        end
      end
    end
  end
end
