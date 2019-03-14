# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/specs/shared_specs'
require 'wings'

RSpec.describe Wings::Valkyrie::Persister do
  before do
    class Book < ActiveFedora::Base
      property :title, predicate: ::RDF::Vocab::DC.title, multiple: true
    end
  end

  after do
    Object.send(:remove_const, :Book)
  end

  subject(:persister) { described_class.new(adapter: adapter) }
  let(:adapter) { Wings::Valkyrie::MetadataAdapter.new }
  let(:query_service) { adapter.query_service }
  let(:af_resource_class) { Book }
  let(:resource_class) { Wings::ModelTransformer.to_valkyrie_resource_class(klass: af_resource_class) }
  let(:resource) { resource_class.new(title: ['Foo']) }

  # it_behaves_like "a Valkyrie::Persister"

  it { is_expected.to respond_to(:save).with_keywords(:resource) }
  it { is_expected.to respond_to(:save_all).with_keywords(:resources) }
  it { is_expected.to respond_to(:delete).with_keywords(:resource) }
  it { is_expected.to respond_to(:wipe!) }

  it "can save a resource" do
    expect(resource).not_to be_persisted
    saved = persister.save(resource: resource)
    expect(saved).to be_persisted
    expect(saved.id).not_to be_blank
  end

  it "stores created_at/updated_at" do
    book = persister.save(resource: resource)
    book.title = ["test"]
    book = persister.save(resource: book)
    expect(book.created_at).not_to be_blank
    expect(book.updated_at).not_to be_blank
    expect(book.created_at).not_to be_kind_of Array
    expect(book.updated_at).not_to be_kind_of Array
    expect(book.updated_at > book.created_at).to eq true
  end

  xit "can override default id generation with a provided id" do
    id = SecureRandom.uuid
    book = persister.save(resource: resource_class.new(id: id, title: ['Foo']))
    expect(book.id).to eq Valkyrie::ID.new(id)
    expect(book).to be_persisted
    expect(book.created_at).not_to be_blank
    expect(book.updated_at).not_to be_blank
    expect(book.created_at).not_to be_kind_of Array
    expect(book.updated_at).not_to be_kind_of Array
  end

  it "doesn't override a resource that already has an ID" do
    book = persister.save(resource: resource_class.new(title: ['Foo']))
    id = book.id
    output = persister.save(resource: book)
    expect(output.id).to eq id
  end

  it "can find that resource again" do
    id = persister.save(resource: resource).id
    expect(query_service.find_by(id: id).internal_resource).to eq resource.internal_resource
  end

  it "can save multiple resources at once" do
    resource2 = resource_class.new
    results = persister.save_all(resources: [resource, resource2])

    expect(results.map(&:id).uniq.length).to eq 2
    expect(persister.save_all(resources: [])).to eq []
  end

  it "can delete objects" do
    persisted = persister.save(resource: resource)
    persister.delete(resource: persisted)
    expect { query_service.find_by(id: persisted.id) }.to raise_error ::Valkyrie::Persistence::ObjectNotFoundError
  end

  it "can delete all objects" do
    resource2 = resource_class.new
    persister.save_all(resources: [resource, resource2])
    persister.wipe!
    expect(query_service.find_all.to_a.length).to eq 0
  end
end
