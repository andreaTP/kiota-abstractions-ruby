# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

RSpec.describe 'writing enum collections' do
  let(:writer) { MicrosoftKiotaSerializationJson::JsonSerializationWriter.new }

  it 'writes a collection of enum values' do
    writer.write_collection_of_enum_values('colours', %i[Red Blue])
    expect(writer.writer).to eq({ 'colours' => %w[Red Blue] })
  end

  it 'leaves an unset collection off the wire' do
    writer.write_collection_of_enum_values('colours', nil)
    expect(writer.writer).to eq({})
  end

  it 'drops nil members' do
    writer.write_collection_of_enum_values('colours', [:Red, nil])
    expect(writer.writer).to eq({ 'colours' => %w[Red] })
  end
end

RSpec.describe 'writing a primitive collection as the document root' do
  let(:writer) { MicrosoftKiotaSerializationJson::JsonSerializationWriter.new }

  it 'writes every element, not just the last' do
    writer.write_collection_of_primitive_values(nil, %w[a b])
    expect(JSON.parse(writer.get_serialized_content)).to eq(%w[a b])
  end

  it 'converts elements that need it' do
    writer.write_collection_of_primitive_values(nil, [Date.new(2026, 1, 2)])
    expect(JSON.parse(writer.get_serialized_content)).to eq(['2026-01-02'])
  end
end

RSpec.describe 'serializing converted scalars as the document root' do
  let(:writer) { MicrosoftKiotaSerializationJson::JsonSerializationWriter.new }

  it 'writes a guid as the root' do
    writer.write_guid_value(nil, UUIDTools::UUID.parse('2b6d5b1a-2b6d-4b1a-8b6d-5b1a2b6d5b1a'))
    expect(JSON.parse(writer.get_serialized_content)).to eq('2b6d5b1a-2b6d-4b1a-8b6d-5b1a2b6d5b1a')
  end

  it 'writes a date as the root' do
    writer.write_date_value(nil, Date.new(2026, 1, 2))
    expect(JSON.parse(writer.get_serialized_content)).to eq('2026-01-02')
  end

  it 'writes a date time as the root' do
    writer.write_date_time_value(nil, DateTime.new(2026, 1, 2, 3, 4, 5))
    expect(JSON.parse(writer.get_serialized_content)).to start_with('2026-01-02T03:04:05')
  end

  it 'keeps booleans and nils in a root primitive collection' do
    writer.write_collection_of_primitive_values(nil, [true, false, nil, 'x'])
    expect(JSON.parse(writer.get_serialized_content)).to eq([true, false, nil, 'x'])
  end
end
