# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

RSpec.describe 'serializing unset scalars' do
  let(:writer) { MicrosoftKiotaSerializationJson::JsonSerializationWriter.new }

  it 'leaves an unset string off the wire' do
    writer.write_string_value('name', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset boolean off the wire' do
    writer.write_boolean_value('active', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset number off the wire' do
    writer.write_number_value('rank', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset float off the wire' do
    writer.write_float_value('ratio', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset guid off the wire' do
    writer.write_guid_value('id', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset date off the wire' do
    writer.write_date_value('day', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset time off the wire' do
    writer.write_time_value('at', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset date time off the wire' do
    writer.write_date_time_value('when', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset duration off the wire' do
    writer.write_duration_value('length', nil)
    expect(writer.writer).to eq({})
  end

  it 'leaves an unset enum off the wire rather than writing an empty string' do
    writer.write_enum_value('colour', nil)
    expect(writer.writer).to eq({})
  end

  it 'raises when both the key and the enum value are missing, like the other writers' do
    expect { writer.write_enum_value(nil, nil) }.to raise_error(StandardError, /no key or value/)
  end

  it 'still writes an enum as the root of the document' do
    writer.write_enum_value(nil, :Red)
    expect(JSON.parse(writer.get_serialized_content)).to eq('Red')
  end

  it 'still writes false, which is set' do
    writer.write_boolean_value('active', false)
    expect(writer.writer).to eq({ 'active' => false })
  end

  it 'still writes zero, which is set' do
    writer.write_number_value('rank', 0)
    expect(writer.writer).to eq({ 'rank' => 0 })
  end

  it 'still writes an empty string, which is set' do
    writer.write_string_value('name', '')
    expect(writer.writer).to eq({ 'name' => '' })
  end

  it 'still writes a set date' do
    writer.write_date_value('day', Date.new(2026, 1, 2))
    expect(writer.writer).to eq({ 'day' => '2026-01-02' })
  end
end
