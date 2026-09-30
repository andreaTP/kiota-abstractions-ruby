# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

RSpec.describe 'reading enums' do
  let(:colour) { { Red: :Red, Green: :Green, Blue: :Blue }.freeze }

  def node_for(json) = MicrosoftKiotaSerializationJson::JsonParseNode.new(JSON.parse(json))

  describe '#get_enum_value' do
    it 'resolves a wire value against the enum definition' do
      expect(node_for('"blue"').get_enum_value(colour)).to eq(:Blue)
    end

    it 'resolves a wire value that already matches the member name' do
      expect(node_for('"Blue"').get_enum_value(colour)).to eq(:Blue)
    end

    it 'returns nil for a member the enum does not declare' do
      expect(node_for('"purple"').get_enum_value(colour)).to be_nil
    end

    it 'resolves a wire value that only a member value carries' do
      access = { IncomingPayment: 'incoming-payment', ReadAll: 'read-all' }.freeze
      expect(node_for('"incoming-payment"').get_enum_value(access)).to eq('incoming-payment')
      expect(node_for('"read-all"').get_enum_value(access)).to eq(access[:ReadAll])
    end
  end

  describe '#get_collection_of_enum_values' do
    it 'reads a JSON array of enum values' do
      expect(node_for('["red","blue"]').get_collection_of_enum_values(colour)).to eq(%i[Red Blue])
    end

    it 'reads a comma separated string, the way a flags enum arrives' do
      expect(node_for('"red,blue"').get_collection_of_enum_values(colour)).to eq(%i[Red Blue])
    end

    it 'drops members the enum does not declare' do
      expect(node_for('["red","purple"]').get_collection_of_enum_values(colour).compact).to eq([:Red])
    end

    it 'reads wire values that only member values carry' do
      actions = { Read: 'read', ReadAll: 'read-all' }.freeze
      expect(node_for('["read","read-all"]').get_collection_of_enum_values(actions)).to eq(%w[read read-all])
    end

    it 'returns an empty collection for an empty string' do
      expect(node_for('""').get_collection_of_enum_values(colour)).to eq([])
    end
  end
end
