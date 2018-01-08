require 'rails_helper'

RSpec.describe Hyrax::Actors::TransferRequestActor do
  let(:ability) { ::Ability.new(depositor) }
  let(:change_set) { GenericWorkChangeSet.new(work) }
  let(:change_set_persister) { double }
  let(:env) { Hyrax::Actors::Environment.new(change_set, change_set_persister, ability, attributes) }
  let(:model_actor) { instance_double(Hyrax::Actors::ModelActor) }
  let(:depositor) { create(:user) }
  let(:work) do
    build(:work, on_behalf_of: proxied_to)
  end
  let(:attributes) { {} }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
    end
    stack.build(model_actor)
  end

  before do
    allow(model_actor).to receive(:create).and_return(work)
  end

  describe "create" do
    context "when on_behalf_of is blank" do
      let(:proxied_to) { '' }

      it "returns true" do
        expect(middleware.create(env)).to be_instance_of GenericWork
      end
    end

    context "when proxied_to is provided" do
      let(:proxied_to) { 'james@example.com' }

      before do
        create(:user, email: proxied_to)
      end

      it "adds the template users to the work" do
        expect(ContentDepositorChangeEventJob).to receive(:perform_later).with(work, User)
        expect(middleware.create(env)).to be_instance_of GenericWork
      end
    end
  end
end
