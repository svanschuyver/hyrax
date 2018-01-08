RSpec.describe Hyrax::Actors::InitializeWorkflowActor do
  let(:user) { create(:user) }
  let(:ability) { ::Ability.new(user) }
  let(:curation_concern) { build(:work) }
  let(:attributes) { { title: ['test'] } }

  let(:model_actor) { Hyrax::Actors::GenericWorkActor.new(nil) }
  let(:change_set) { GenericWorkChangeSet.new(curation_concern) }
  let(:change_set_persister) { Hyrax::ChangeSetPersister.new(metadata_adapter: Valkyrie::MetadataAdapter.find(:indexing_persister), storage_adapter: Valkyrie.config.storage_adapter) }
  let(:env) { Hyrax::Actors::Environment.new(change_set, change_set_persister, ability, attributes) }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
    end
    stack.build(model_actor)
  end

  describe 'the next actor' do
    it 'passes the attributes on' do
      expect(model_actor).to receive(:create).with(Hyrax::Actors::Environment)
      subject.create(env)
    end
  end

  describe 'create' do
    let(:curation_concern) { build(:work, admin_set_id: admin_set.id) }
    let!(:admin_set) { create_for_repository(:admin_set, with_permission_template: { with_workflows: true }) }

    it 'creates an entity' do
      expect do
        expect(subject.create(env)).to be_instance_of GenericWork
      end.to change { Sipity::Entity.count }.by(1)
    end
  end
end
