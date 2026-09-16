# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

module ComposedDeserializationModels
  class Cat
    include MicrosoftKiotaAbstractions::Parsable

    attr_accessor :meows

    def get_field_deserializers = { 'meows' => ->(n) { @meows = n.get_boolean_value } }
    def serialize(writer) = writer.write_boolean_value('meows', @meows)
    def self.create_from_discriminator_value(_parse_node) = Cat.new
  end

  class Pet
    include MicrosoftKiotaAbstractions::Parsable

    attr_accessor :cat, :string

    def get_field_deserializers
      return @cat.get_field_deserializers unless @cat.nil?

      {}
    end

    def serialize(writer); end

    def self.create_from_discriminator_value(parse_node)
      result = Pet.new
      val = parse_node.get_string_value
      result.string = val unless val.nil?
      result
    end
  end
end

RSpec.describe 'deserializing a composed type wrapper' do
  def node_for(json) = MicrosoftKiotaSerializationJson::JsonParseNode.new(JSON.parse(json))

  let(:factory) { ->(pn) { ComposedDeserializationModels::Pet.create_from_discriminator_value(pn) } }

  it 'reads a union whose payload is a primitive at the root' do
    result = node_for('"just-a-string"').get_object_value(factory)
    expect(result.string).to eq('just-a-string')
  end

  it 'reads a union whose payload is an object no member claims' do
    result = node_for('{"meows":true}').get_object_value(factory)
    expect(result).to be_a(ComposedDeserializationModels::Pet)
  end

  it 'still fills additional_data on a model that holds it' do
    holder = Class.new do
      include MicrosoftKiotaAbstractions::Parsable

      include MicrosoftKiotaAbstractions::AdditionalDataHolder

      def get_field_deserializers = {}
      def serialize(writer); end
    end
    result = node_for('{"unexpected":1}').get_object_value(->(_pn) { holder.new })
    expect(result.additional_data).to eq({ 'unexpected' => 1 })
  end
end
