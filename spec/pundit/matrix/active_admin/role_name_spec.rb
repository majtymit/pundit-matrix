RSpec.describe Pundit::Matrix::ActiveAdmin::RoleName do
  let(:namespace) do
    registering = Class.new { def register(resource_class, options = {}) = [resource_class, options] }
    Class.new(registering) { prepend Pundit::Matrix::ActiveAdmin::RoleName }.new
  end

  it 'registers roles as Role, so a reopening block without a name finds the same screen' do
    expect(namespace.register(Pundit::Matrix::Role)).to eq([Pundit::Matrix::Role, { as: 'Role' }])
    expect(namespace.register(Pundit::Matrix::Role, namespace: :admin))
      .to eq([Pundit::Matrix::Role, { as: 'Role', namespace: :admin }])
  end

  it 'keeps a name the app gives and leaves other resources alone' do
    expect(namespace.register(Pundit::Matrix::Role, as: 'Group')).to eq([Pundit::Matrix::Role, { as: 'Group' }])
    expect(namespace.register(Widget)).to eq([Widget, {}])
  end
end
