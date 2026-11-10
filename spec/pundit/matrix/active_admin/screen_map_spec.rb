RSpec.describe Pundit::Matrix::ActiveAdmin::ScreenMap do
  let(:namespace) { ActiveAdmin.application.namespaces[:admin] }
  let(:map) { described_class.new(namespace) }

  before { ActiveAdmin.application.load! }

  def place(**)
    Pundit::Matrix::Layout::Place.new(group: nil, group_label: nil, group_priority: nil, **)
  end

  describe '#places' do
    it 'places each screen where its registration sits in the menu, with the text of the labels' do
      view = ActionController::Base.new.view_context

      expect(map.places(view)).to eq(
        reports: place(priority: 1, label: 'Reports'),
        users: place(group: :access, group_label: 'Access', group_priority: 3, priority: 2, label: 'Users'),
        widgets: place(priority: 5, label: 'Gadgets')
      )
    end

    it 'leaves a registration out of the menu to one that is shown' do
      widgets = namespace.resource_for(Widget)
      allow(widgets).to receive(:include_in_menu?).and_return(false)

      expect(map.places(ActionController::Base.new.view_context)).not_to have_key(:widgets)
    end
  end

  describe '#conflicts' do
    it 'has none while every screen sits under one parent' do
      expect(map.conflicts).to be_empty
    end

    it 'names a screen the menu shows under two parents, with the registrations under each' do
      allow(Admin::WidgetPolicy).to receive(:matrix_screen).and_return(:reports)
      widgets = namespace.resource_for(Widget)
      allow(widgets).to receive(:menu_item_options).and_return(widgets.menu_item_options.merge(parent: 'access'))

      expect(map.conflicts).to eq(['Screen reports sits under no parent (Reports) and access (Widget)'])
    end
  end

  describe '#level_mismatches' do
    include_context 'with fresh configuration'

    let(:subject_user) { User.create!(email: 'a@example.com') }

    def draw(widgets: false, reports: true)
      Pundit::Matrix.screens.draw do
        screen :users
        screen :widgets, read_only: widgets
        screen :reports, read_only: reports
      end
    end

    it 'has none while read-only screens offer no write and writable ones do' do
      draw

      expect(map.level_mismatches(subject_user)).to be_empty
    end

    it 'names the actions a read-only screen offers that need write' do
      draw(widgets: true)

      expect(map.level_mismatches(subject_user)).to eq(
        ['Screen widgets is read-only, but these actions need write: Widget#create, Widget#update, Widget#destroy']
      )
    end

    it 'names a writable screen with nothing to write' do
      draw(reports: false)

      expect(map.level_mismatches(subject_user))
        .to eq(['Screen reports is writable, but none of its actions needs write'])
    end

    it 'counts an action of another screen for that screen' do
      draw(reports: false)
      allow(Admin::WidgetPolicy).to receive(:matrix_screen_actions).and_return(publish: :reports)

      expect(map.level_mismatches(subject_user)).to be_empty
    end

    it 'leaves out the actions the policy switches off' do
      draw(widgets: true)
      switched_off = Class.new(ApplicationPolicy) do
        screen :widgets
        actions_of_screen :users, :publish

        def create? = false
        def update? = false
        def destroy? = false
      end
      stub_const('Admin::WidgetPolicy', switched_off)

      expect(map.level_mismatches(subject_user)).to be_empty
    end

    it 'asks the policy about the class, whether the action exists at all, not about a row' do
      draw
      row_dependent = Class.new(ApplicationPolicy) do
        screen :widgets
        actions_of_screen :users, :publish

        def create? = false
        def destroy? = false
        def update? = record.is_a?(Class) || record.secret?
      end
      stub_const('Admin::WidgetPolicy', row_dependent)

      expect(map.level_mismatches(subject_user)).to be_empty
    end

    it 'counts a member action read with GET and sent with POST, allowed only for some rows' do
      draw
      widgets = namespace.resource_for(Widget)
      allow(widgets).to receive(:member_actions)
        .and_return([ActiveAdmin::ControllerAction.new(:deletion, method: %i[get post])])
      row_dependent = Class.new(ApplicationPolicy) do
        screen :widgets

        def create? = false
        def update? = false
        def destroy? = false
        def deletion? = record.is_a?(Class) || record.secret?
      end
      stub_const('Admin::WidgetPolicy', row_dependent)

      expect(map.level_mismatches(subject_user)).to be_empty
    end

    it 'leaves out what the app keeps outside the matrix, and builds no record, which a model without a table cannot' do
      draw
      stub_const('Admin::ActiveAdmin::CommentPolicy', Class.new(ApplicationPolicy) { screen :reports })

      expect(map.level_mismatches(subject_user).join).to include('Comment#create')
      expect(described_class.new(namespace, except: %w[Comment]).level_mismatches(subject_user)).to be_empty
    end

    it 'counts only the page actions of a page, and only those not read with GET' do
      draw
      reports = namespace.resources.find { |resource| resource.resource_name.to_s == 'Reports' }
      actions = [ActiveAdmin::ControllerAction.new(:export, method: :post), ActiveAdmin::ControllerAction.new(:preview)]
      allow(reports).to receive(:page_actions).and_return(actions)
      page_policy = Class.new(Pundit::Matrix::ActiveAdmin::PagePolicy) do
        def export? = write?
        def preview? = true
      end
      stub_const('Admin::ActiveAdmin::PagePolicy', page_policy)

      expect(map.level_mismatches(subject_user))
        .to eq(['Screen reports is read-only, but these actions need write: Reports#export'])
    end
  end
end
