# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

module ReaderShapeModels
  class Item
    include MicrosoftKiotaAbstractions::Parsable

    attr_accessor :name

    def get_field_deserializers = { 'name' => ->(n) { @name = n.get_string_value } }
    def serialize(writer) = writer.write_string_value('name', @name)
    def self.create_from_discriminator_value(_parse_node) = Item.new
  end
end

# A composed type wrapper reads every member before choosing one, so each reader meets payloads
# shaped for the other members. It has to answer nil for those rather than raise or invent a value.
RSpec.describe 'readers given a node of another shape' do
  let(:colour) { { Red: 'red', Blue: 'blue' }.freeze }

  def node_for(json) = MicrosoftKiotaSerializationJson::JsonParseNode.new(JSON.parse(json))

  others = { 'a number' => '42', 'an object' => '{"name": "a"}', 'an array' => '["2026-01-02"]', 'a boolean' => 'true' }

  describe 'the date, time, duration and guid readers' do
    readers = {
      get_date_value: '"2026-01-02"',
      get_time_value: '"10:11:12"',
      get_date_time_value: '"2026-01-02T10:11:12Z"',
      get_duration_value: '"PT1H"',
      get_guid_value: '"2b6d5b1a-2b6d-4b1a-8b6d-5b1a2b6d5b1a"'
    }

    readers.each do |reader, valid|
      others.each do |shape, json|
        it "#{reader} answers nil for #{shape}" do
          expect(node_for(json).public_send(reader)).to be_nil
        end
      end

      it "#{reader} still reads a string" do
        expect(node_for(valid).public_send(reader)).not_to be_nil
      end
    end
  end

  describe 'the collection readers' do
    non_arrays = { 'a number' => '42', 'an object' => '{"name": "a"}', 'a string' => '"a"' }

    non_arrays.each do |shape, json|
      it "reads no objects from #{shape}" do
        expect(node_for(json).get_collection_of_object_values(ReaderShapeModels::Item.method(:create_from_discriminator_value))).to be_nil
      end

      it "reads no primitives from #{shape}" do
        expect(node_for(json).get_collection_of_primitive_values(String)).to be_nil
      end
    end

    it 'reads no enum values from an object' do
      expect(node_for('{"name": "red"}').get_collection_of_enum_values(colour)).to be_nil
    end

    it 'reads no enum values from a number' do
      expect(node_for('42').get_collection_of_enum_values(colour)).to be_nil
    end

    it 'still reads an array' do
      items = node_for('[{"name": "a"}]').get_collection_of_object_values(ReaderShapeModels::Item.method(:create_from_discriminator_value))
      expect(items.map(&:name)).to eq(%w[a])
    end
  end

  describe 'get_child_node' do
    it 'finds no child in an array' do
      expect(node_for('[{"type": "file"}]').get_child_node('type')).to be_nil
    end

    it 'finds no child in a string that happens to contain the name' do
      expect(node_for('"filetype"').get_child_node('type')).to be_nil
    end

    it 'finds no child in a number' do
      expect(node_for('42').get_child_node('type')).to be_nil
    end

    it 'still finds a child in an object' do
      expect(node_for('{"type": "file"}').get_child_node('type').get_string_value).to eq('file')
    end
  end
end
