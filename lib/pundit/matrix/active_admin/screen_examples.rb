module Pundit
  module Matrix
    module ActiveAdmin
      module ScreenExamples
        def screen_map
          ScreenMap.new(matrix_namespace, except: outside_the_matrix)
        end

        def screens
          @screens ||= matrix_namespace.resources.filter_map do |resource|
            screen_of(resource) unless resource.resource_name.to_s.in?(outside_the_matrix)
          end
        end

        def screens_with(kind)
          screens.select { |screen| screen[:access] == kind }
        end

        def authorized?(screen, subject, action)
          adapter(screen[:resource], subject).authorized?(action.to_sym, screen[:resource].resource_class)
        end

        # Asked about the model, the way a screen asks whether a button exists at all.
        def answers(screen, subject)
          return {} if screen[:resource].is_a?(::ActiveAdmin::Page)

          actions = actions_of(screen[:resource]) - actions_of_other_screens(screen).keys.map(&:to_s)
          actions.index_with { |action| authorized?(screen, subject, action) }
        end

        def actions_of_other_screens(screen)
          resource = screen[:resource]
          return {} if resource.is_a?(::ActiveAdmin::Page)

          adapter(resource, nil).retrieve_policy(resource.resource_class).class.try(:matrix_screen_actions) || {}
        end

        def other_screen_read(key)
          other = Pundit::Matrix.screens.find { |screen| screen.key != key }
          other ? { other.key => :read } : {}
        end

        def menu_paths_of(key)
          screens.select { |screen| screen[:key] == key && screen[:in_menu] }.map { |screen| screen[:path] }
        end

        def open_paths
          [root_path_of_namespace, *screens_with(:open).map { |screen| screen[:path] }]
        end

        def menu_paths
          links = Nokogiri::HTML(response.body).css("#tabs a[href^=\"#{root_path_of_namespace}\"]")
          links.map { |link| link['href'] }.uniq
        end

        private

        def screen_of(resource)
          kind, key = Registration.new(resource).access
          {
            name: resource.resource_name.to_s,
            access: kind,
            key:,
            path: resource.route_collection_path,
            in_menu: resource.include_in_menu?,
            resource:,
          }
        end

        def actions_of(resource)
          (resource.controller.action_methods & %w[new create edit update destroy]).to_a +
            (resource.member_actions + resource.collection_actions).map { |action| action.name.to_s }
        end

        def adapter(resource, subject)
          ::ActiveAdmin::PunditAdapter.new(resource, subject)
        end

        def root_path_of_namespace
          "/#{matrix_namespace.name}"
        end
      end
    end
  end
end

# Holds every resource and page of a namespace to the matrix: an address needs its level, the menu shows only what
# is open, read offers no change and write offers what an admin gets.
RSpec.shared_examples 'Pundit::Matrix screens' do |create_subject:,
                                                   namespace: ActiveAdmin.application.default_namespace,
                                                   except: []|
  include Pundit::Matrix::ActiveAdmin::ScreenExamples

  let(:matrix_namespace) { ActiveAdmin.application.namespaces[namespace] }
  let(:outside_the_matrix) { except }

  define_method(:new_subject) { instance_exec(&create_subject) }

  before { ActiveAdmin.application.load! }

  it 'gives every resource and page a screen, an admin screen or an open screen' do
    expect(screens.reject { |screen| screen[:access] }.map { |screen| screen[:name] }).to be_empty
  end

  it 'places every screen under one menu parent, so the matrix takes its group from the menu' do
    expect(screen_map.conflicts).to be_empty
  end

  it 'offers write on a screen exactly when one of its actions needs write' do
    expect(screen_map.level_mismatches(new_subject)).to be_empty
  end

  it 'refuses a screen without its level' do
    screens_with(:screen).each do |screen|
      sign_in grant_levels(new_subject, **other_screen_read(screen[:key]))

      get screen[:path]

      expect(response).to have_http_status(:redirect), screen[:name]
    end
  end

  it 'opens a screen with read, shows only its screen in the menu and offers no change' do
    screens_with(:screen).each do |screen|
      someone = grant_levels(new_subject, screen[:key] => :read)
      sign_in someone

      get screen[:path]

      expect(response).to have_http_status(:ok), screen[:name]
      expect(menu_paths - open_paths).to match_array(menu_paths_of(screen[:key])), screen[:name]
      expect(answers(screen, someone).values).to all(be(false)), screen[:name]
    end
  end

  it 'offers with write what an admin gets' do
    admin = make_admin(new_subject)

    screens_with(:screen).reject { |screen| Pundit::Matrix.screens.fetch(screen[:key]).read_only? }.each do |screen|
      someone = grant_levels(new_subject, screen[:key] => :write)

      expect(answers(screen, someone)).to eq(answers(screen, admin)), screen[:name]
    end
  end

  it 'leaves the actions of another screen to whoever writes there' do
    screens_with(:screen).each do |screen|
      actions_of_other_screens(screen).each do |action, key|
        someone = grant_levels(new_subject, key => :write)

        expect(authorized?(screen, someone, action)).to be(true), "#{screen[:name]} #{action}"
      end
    end
  end

  it 'opens an admin screen to admins only' do
    admin = make_admin(new_subject)
    highest_levels = Pundit::Matrix.screens.to_h { |screen| [screen.key, screen.levels.last] }
    everything = grant_levels(new_subject, **highest_levels)

    screens_with(:admin).each do |screen|
      sign_in admin
      get screen[:path]
      expect(response).to have_http_status(:ok), screen[:name]

      sign_in everything
      get screen[:path]
      expect(response).to have_http_status(:redirect), screen[:name]
    end
  end

  it 'opens an open screen to everyone signed in' do
    screens_with(:open).each do |screen|
      sign_in new_subject

      get screen[:path]

      expect(response).to have_http_status(:ok), screen[:name]
    end
  end
end
