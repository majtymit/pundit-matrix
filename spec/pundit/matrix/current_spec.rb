RSpec.describe Pundit::Matrix::Current do
  let(:user) { User.create!(email: 'a@example.com') }

  it 'has no actor outside a request' do
    expect(described_class.actor).to be_nil
  end

  it 'takes an actor for a block' do
    described_class.set(actor: user) { expect(described_class.actor).to eq(user) }

    expect(described_class.actor).to be_nil
  end

  it 'resolves the actor only when asked' do
    calls = 0
    source = lambda do
      calls += 1
      user
    end

    described_class.set(actor_source: source) do
      expect(calls).to eq(0)
      expect(described_class.actor).to eq(user)
    end
  end

  it 'prefers an actor given for a block and restores the outer one after it' do
    other = User.create!(email: 'b@example.com')

    described_class.set(actor_source: -> { user }) do
      described_class.set(actor: other) { expect(described_class.actor).to eq(other) }
      described_class.set { expect(described_class.actor).to be_nil }
      expect(described_class.actor).to eq(user)
    end

    expect(described_class.actor).to be_nil
  end
end
