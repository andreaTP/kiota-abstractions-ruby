# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

RSpec.describe MicrosoftKiotaAbstractions::RequestInformation do
  subject(:request_info) { described_class.new }

  let(:writer) { double('writer') }
  let(:factory) { double('factory') }
  let(:adapter) { double('adapter') }

  before do
    allow(adapter).to receive(:get_serialization_writer_factory).and_return(factory)
    allow(factory).to receive(:get_serialization_writer).with('application/json').and_return(writer)
    allow(writer).to receive(:get_serialized_content).and_return('serialized')
  end

  it 'writes a string body through the string writer' do
    expect(writer).to receive(:write_string_value).with(nil, 'hello')
    request_info.set_content_from_scalar(adapter, 'application/json', 'hello')
    expect(request_info.content).to eq('serialized')
  end

  it 'writes an integer body through the number writer' do
    expect(writer).to receive(:write_number_value).with(nil, 42)
    request_info.set_content_from_scalar(adapter, 'application/json', 42)
  end

  it 'writes a boolean body through the boolean writer' do
    expect(writer).to receive(:write_boolean_value).with(nil, true)
    request_info.set_content_from_scalar(adapter, 'application/json', true)
  end

  it 'writes a collection body through the primitive collection writer' do
    expect(writer).to receive(:write_collection_of_primitive_values).with(nil, %w[a b])
    request_info.set_content_from_scalar(adapter, 'application/json', %w[a b])
  end

  it 'writes an enum body through the enum writer' do
    expect(writer).to receive(:write_enum_value).with(nil, :Blue)
    request_info.set_content_from_scalar(adapter, 'application/json', :Blue)
  end

  it 'raises for a type it cannot serialize' do
    expect { request_info.set_content_from_scalar(adapter, 'application/json', Object.new) }
      .to raise_error(StandardError, /unknown type/)
  end

  it 'sets the content type header' do
    allow(writer).to receive(:write_string_value)
    request_info.set_content_from_scalar(adapter, 'application/json', 'hello')
    expect(request_info.headers.get_all['Content-Type']).to include('application/json')
  end
end
