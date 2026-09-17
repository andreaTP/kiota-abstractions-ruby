# frozen_string_literal: true

require 'stringio'

RSpec.describe MicrosoftKiotaFaraday::FaradayRequestAdapter do
  subject(:adapter) do
    described_class.new(authentication_provider, parse_node_factory, nil, client).tap do |a|
      a.set_base_url('https://example.com')
    end
  end

  let(:authentication_provider) { double('authentication_provider') }
  let(:parse_node_factory) { double('parse_node_factory') }
  let(:parse_node) { double('parse_node') }
  let(:client) { double('client') }
  let(:headers) { { 'content-type' => 'application/json' } }
  let(:factory) { ->(_pn) {} }

  let(:request_info) do
    info = MicrosoftKiotaAbstractions::RequestInformation.new
    info.http_method = :GET
    info.url_template = '{+baseurl}/things'
    info.path_parameters = { 'baseurl' => 'https://example.com' }
    info
  end

  def respond_with(body, status: 200, response_headers: headers)
    response = instance_double(Faraday::Response, status:, body:, headers: response_headers)
    allow(client).to receive(:build_request).and_return(Faraday::Request.create(:get))
    allow(client).to receive(:run_request).and_return(response)
    response
  end

  before do
    allow(authentication_provider).to receive(:authenticate_request).and_return(Fiber.new { nil })
    allow(parse_node_factory).to receive(:get_parse_node).and_return(parse_node)
  end

  describe '#send_no_response_content_async' do
    it 'returns without parsing a body' do
      respond_with('', status: 204, response_headers: {})
      expect(parse_node_factory).not_to receive(:get_parse_node)
      expect(adapter.send_no_response_content_async(request_info, nil).resume).to be_nil
    end
  end

  describe '#send_collection_async' do
    it 'reads the payload as a collection of objects' do
      respond_with('[{"name":"a"},{"name":"b"}]')
      allow(parse_node).to receive(:get_collection_of_object_values).with(factory).and_return(%w[a b])
      expect(adapter.send_collection_async(request_info, factory, nil).resume).to eq(%w[a b])
    end
  end

  describe '#send_collection_of_primitive_async' do
    it 'reads the payload as a collection of primitives' do
      respond_with('["a","b"]')
      allow(parse_node).to receive(:get_collection_of_primitive_values).with(String).and_return(%w[a b])
      expect(adapter.send_collection_of_primitive_async(request_info, String, nil).resume).to eq(%w[a b])
    end
  end

  describe '#send_collection_of_primitive_async with an enum' do
    it 'reads the payload as a collection of enum values' do
      colour = { Red: :Red, Blue: :Blue }.freeze
      respond_with('["red","blue"]')
      allow(parse_node).to receive(:get_collection_of_enum_values).with(colour).and_return(%i[Red Blue])
      expect(adapter.send_collection_of_primitive_async(request_info, colour, nil).resume).to eq(%i[Red Blue])
    end
  end

  describe '#send_primitive_async' do
    it 'reads a scalar through the matching parse node getter' do
      respond_with('"hello"')
      allow(parse_node).to receive(:get_string_value).and_return('hello')
      expect(adapter.send_primitive_async(request_info, String, nil).resume).to eq('hello')
    end

    it 'reads an enum through get_enum_value' do
      colour = { Red: :Red, Green: :Green }.freeze
      respond_with('"Red"')
      allow(parse_node).to receive(:get_enum_value).with(colour).and_return(:Red)
      expect(adapter.send_primitive_async(request_info, colour, nil).resume).to eq(:Red)
    end

    it 'returns the raw body for a binary response without parsing it' do
      respond_with('rawbytes', response_headers: { 'content-type' => 'application/octet-stream' })
      expect(parse_node_factory).not_to receive(:get_parse_node)
      expect(adapter.send_primitive_async(request_info, StringIO, nil).resume.read).to eq('rawbytes')
    end
  end
  describe '#send_primitive_async with an empty binary response' do
    it 'returns nil rather than an empty stream' do
      respond_with('', status: 204, response_headers: {})
      expect(adapter.send_primitive_async(request_info, StringIO, nil).resume).to be_nil
    end
  end

  describe 'an empty response with no content type' do
    it 'returns nil from send_async rather than raising' do
      respond_with('', status: 204, response_headers: {})
      expect(adapter.send_async(request_info, factory, nil).resume).to be_nil
    end

    it 'returns nil from send_collection_async rather than raising' do
      respond_with('', status: 204, response_headers: {})
      expect(adapter.send_collection_async(request_info, factory, nil).resume).to be_nil
    end
  end
end
