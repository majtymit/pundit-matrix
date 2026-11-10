RSpec.describe Pundit::Matrix::ActiveAdmin::Registration::WriteEverywhere do
  it 'stands in for a subject with write on every screen, answering the rest as the subject' do
    user = User.create!(email: 'a@example.com')
    granted = described_class.new(user)

    expect(granted.access.level(:anything)).to eq(:write)
    expect(%i[read? write? manage? assign?].map { |question| granted.access.public_send(question, :x) })
      .to all(be(true))
    expect(%i[everything? any? superadmin?].map { |question| granted.access.public_send(question) }).to all(be(true))
    expect(granted.email).to eq('a@example.com')
  end
end
