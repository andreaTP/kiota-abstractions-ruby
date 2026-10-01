# frozen_string_literal: true

require_relative '../lib/microsoft_kiota_abstractions/api_error'

RSpec.describe MicrosoftKiotaAbstractions::ApiError do
  it 'takes the response status code and headers with the message' do
    error = described_class.new('not found', response_status_code: 404, response_headers: { 'x-id' => '1' })

    expect([error.message, error.response_status_code, error.response_headers]).to eq(['not found', 404, { 'x-id' => '1' }])
  end

  it 'still builds through the bare super a generated error calls' do
    generated = Class.new(described_class) do
      def initialize
        super
        @additional_data = {}
      end
    end

    error = generated.new
    expect([error.response_status_code, error.response_headers]).to eq([nil, nil])
  end
end
