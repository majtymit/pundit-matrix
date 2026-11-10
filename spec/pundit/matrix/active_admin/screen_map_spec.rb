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
end
