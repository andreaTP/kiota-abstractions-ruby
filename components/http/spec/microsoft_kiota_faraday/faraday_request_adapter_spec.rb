# frozen_string_literal: true

RSpec.describe MicrosoftKiotaFaraday::FaradayRequestAdapter do
  subject(:adapter) { described_class.new(authentication_provider) }

  let(:authentication_provider) { double('authentication_provider') }
  let(:headers) { { 'content-type' => 'application/json' } }
  let(:body) { { key: 'value' }.to_json }

  describe '#throw_if_failed_reponse' do
    subject(:adapter) { described_class.new(authentication_provider, parse_node_factory) }

    let(:parse_node_factory) { double('parse_node_factory') }
    let(:parse_node) { double('parse_node') }
    let(:error) { MicrosoftKiotaAbstractions::ApiError.new('bad name') }
    let(:factory) { ->(_pn) { error } }
    let(:response) { instance_double(Faraday::Response, status: 400, body:, headers:) }

    before do
      allow(parse_node_factory).to receive(:get_parse_node).with('application/json', body).and_return(parse_node)
      allow(parse_node).to receive(:get_object_value).with(factory).and_return(error)
    end

    it 'matches an exact status code keyed as a String, the way generated clients write it' do
      expect { adapter.throw_if_failed_reponse(response, { '400' => factory }) }
        .to raise_error(error)
    end

    it 'still matches a wildcard key' do
      expect { adapter.throw_if_failed_reponse(response, { '4XX' => factory }) }
        .to raise_error(error)
    end

    it 'raises a generic ApiError when nothing matches' do
      expect { adapter.throw_if_failed_reponse(response, { '404' => factory }) }
        .to raise_error(MicrosoftKiotaAbstractions::ApiError, /no error factory is registered/)
    end

    it 'returns without raising for a successful response' do
      ok = instance_double(Faraday::Response, status: 200, body:, headers:)
      expect { adapter.throw_if_failed_reponse(ok, {}) }.not_to raise_error
    end
  end

  describe '#get_request_from_request_info' do
    let(:request_info) do
      MicrosoftKiotaAbstractions::RequestInformation.new.tap do |info|
        info.http_method = :QUERY
        info.uri = 'https://example.com/items'
      end
    end

    it 'builds a native QUERY request' do
      expect(adapter.client).to receive(:build_request).with(:query).and_call_original

      expect(adapter.get_request_from_request_info(request_info).http_method).to eq(:query)
    end
  end

  describe '#get_root_parse_node' do
    context 'when response is null' do
      it 'raises an error' do
        expect { adapter.get_root_parse_node(nil) }.to raise_error(StandardError, 'response cannot be null')
      end
    end

    context 'when response content type is not found' do
      let(:response) { instance_double(Faraday::Response, body:, headers: {}) }

      it 'raises an error' do
        expect do
          adapter.get_root_parse_node(response)
        end.to raise_error(StandardError,
                           'no response content type found for deserialization')
      end
    end

    context 'when response body is nil' do
      let(:response) { instance_double(Faraday::Response, body: nil, headers:) }

      it 'returns nil' do
        expect(adapter.get_root_parse_node(response)).to be_nil
      end
    end

    context 'when response body is empty' do
      let(:response) { instance_double(Faraday::Response, body: '', headers:) }

      it 'returns nil' do
        expect(adapter.get_root_parse_node(response)).to be_nil
      end
    end

    context 'when response body is not nil' do
      subject(:adapter) { described_class.new(authentication_provider, parse_node_factory) }

      let(:response) { instance_double(Faraday::Response, body:, headers:) }
      let(:parse_node_factory) { double('parse_node_factory') }
      let(:parse_node) { double('parse_node') }

      before do
        allow(parse_node_factory).to receive(:get_parse_node).with('application/json', body).and_return(parse_node)
      end

      it 'returns the parse node' do
        expect(adapter.get_root_parse_node(response)).to eq(parse_node)
      end
    end
  end
end
