# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

module BackedJsonModels
  # shaped like a model generated with the backing store enabled
  class User
    include MicrosoftKiotaAbstractions::Parsable
    include MicrosoftKiotaAbstractions::BackedModel

    def self.create_from_discriminator_value(_parse_node) = User.new

    def initialize
      @backing_store = MicrosoftKiotaAbstractions::BackingStoreFactorySingleton.instance.create_backing_store
    end

    %w[id name phone manager colleagues].each do |property|
      define_method(property) { @backing_store.get(property) }
      define_method("#{property}=") { |value| @backing_store.set(property, value) }
    end

    def get_field_deserializers
      {
        'id' => ->(n) { self.id = n.get_string_value },
        'name' => ->(n) { self.name = n.get_string_value },
        'phone' => ->(n) { self.phone = n.get_string_value },
        'manager' => ->(n) { self.manager = n.get_object_value(->(pn) { User.create_from_discriminator_value(pn) }) },
        'colleagues' => ->(n) { self.colleagues = n.get_collection_of_object_values(->(pn) { User.create_from_discriminator_value(pn) }) }
      }
    end

    def serialize(writer)
      writer.write_string_value('id', id)
      writer.write_string_value('name', name)
      writer.write_string_value('phone', phone)
      writer.write_object_value('manager', manager)
      writer.write_collection_of_object_values('colleagues', colleagues)
    end
  end
end

RSpec.describe 'a model with a backing store' do
  let(:parse_nodes) { MicrosoftKiotaAbstractions::BackingStoreParseNodeFactory.new(MicrosoftKiotaSerializationJson::JsonParseNodeFactory.new) }
  let(:writers) do
    MicrosoftKiotaAbstractions::BackingStoreSerializationWriterProxyFactory.new(MicrosoftKiotaSerializationJson::JsonSerializationWriterFactory.new)
  end

  def read(json)
    parse_nodes.get_parse_node('application/json', json)
               .get_object_value(->(pn) { BackedJsonModels::User.create_from_discriminator_value(pn) })
  end

  def write(model)
    writer = writers.get_serialization_writer('application/json')
    writer.write_object_value(nil, model)
    JSON.parse(writer.get_serialized_content)
  end

  let(:user) { read('{"id":"u1","name":"Ann","phone":"123","manager":{"id":"m1","name":"Boss"}}') }

  it 'reads every value' do
    expect([user.id, user.name, user.phone, user.manager.name]).to eq(%w[u1 Ann 123 Boss])
  end

  it 'writes nothing when nothing changed after reading' do
    expect(write(user)).to eq({})
  end

  it 'writes only what changed, a null for what was cleared, and the changes of a nested model' do
    user.name = 'Bea'
    user.phone = nil
    user.manager.name = 'Chief'
    expect(write(user)).to eq({ 'name' => 'Bea', 'phone' => nil, 'manager' => { 'name' => 'Chief' } })
  end

  it 'writes the changes of a model each time it appears in the document' do
    colleague = user.manager
    colleague.name = 'Chief'
    user.colleagues = [colleague, colleague]
    expect(write(user)['colleagues']).to eq([{ 'name' => 'Chief' }, { 'name' => 'Chief' }])
  end

  it 'keeps the changes, and reads every value again, when writing fails' do
    user.name = 'Bea'
    user.manager.name = 'Chief'
    user.manager.define_singleton_method(:serialize) { |_writer| raise 'broken' }
    expect { write(user) }.to raise_error(RuntimeError, 'broken')
    expect([user.phone, user.manager.id]).to eq(%w[123 m1])
    user.manager.singleton_class.remove_method(:serialize)
    expect(write(user)).to eq({ 'name' => 'Bea', 'manager' => { 'name' => 'Chief' } })
  end

  it 'clears the changes it wrote even when called while another error is being handled' do
    user.name = 'Bea'
    begin
      raise 'unrelated'
    rescue StandardError
      write(user)
    end
    expect(write(user)).to eq({})
  end

  it 'writes every value set on a new model' do
    fresh = BackedJsonModels::User.new
    fresh.id = 'n1'
    fresh.name = 'New'
    expect(write(fresh)).to eq({ 'id' => 'n1', 'name' => 'New' })
  end
end
