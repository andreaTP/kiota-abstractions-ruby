# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider do
  let(:context) do
    MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', 'client_secret', {})
  end
  let(:allowed_hosts) { ['api.example.com'] }
  let(:provider) { described_class.new(context, allowed_hosts, ['https://api.example.com/.default']) }
  let(:token) { instance_double(OAuth2::AccessToken, token: 'test_token', to_hash: {}) }

  before do
    allow(context).to receive(:get_token).and_return(token)
    allow(context).to receive(:initialize_scopes)
  end

  it 'returns a fiber yielding nil for a host outside the allowed hosts' do
    result = provider.get_authorization_token('https://other.example.com')

    expect(result).to be_a(Fiber)
    expect(result.resume).to be_nil
    expect(context).not_to have_received(:initialize_scopes)
    expect(context).not_to have_received(:get_token)
  end

  it 'returns a fiber yielding nil for a missing URI' do
    result = provider.get_authorization_token(nil)

    expect(result).to be_a(Fiber)
    expect(result.resume).to be_nil
    expect(context).not_to have_received(:get_token)
  end

  it 'returns a token for an allowed host' do
    expect(provider.get_authorization_token('https://api.example.com').resume).to eq('test_token')
    expect(context).to have_received(:get_token).once
  end

  context 'with no allowed hosts configured' do
    let(:allowed_hosts) { [] }

    it 'returns a token for any HTTPS host' do
      expect(provider.get_authorization_token('https://other.example.com').resume).to eq('test_token')
    end
  end

  context 'with request-derived default scopes' do
    let(:allowed_hosts) { %w[one.example.com two.example.com] }
    let(:provider) { described_class.new(context, allowed_hosts) }
    let(:tokens) do
      [
        instance_double(OAuth2::AccessToken, token: 'one_token', to_hash: {}),
        instance_double(OAuth2::AccessToken, token: 'two_token', to_hash: {})
      ]
    end

    it 'derives the default scope for each request without mutating configured scopes' do
      allow(context).to receive(:get_token).and_return(*tokens)

      expect(provider.get_authorization_token('https://one.example.com').resume).to eq('one_token')
      expect(provider.get_authorization_token('https://two.example.com').resume).to eq('two_token')

      expect(context).to have_received(:initialize_scopes).with(['https://one.example.com/.default'])
      expect(context).to have_received(:initialize_scopes).with(['https://two.example.com/.default'])
      expect(context).to have_received(:get_token).twice
      expect(provider.scopes).to eq([])
    end

    it 'reuses a cached token only for its effective scopes' do
      one_token = OAuth2::AccessToken.new(context.oauth_provider, 'one_token', expires_in: 3600)
      two_token = OAuth2::AccessToken.new(context.oauth_provider, 'two_token', expires_in: 3600)
      allow(context).to receive(:get_token).and_return(one_token, two_token)

      expect(provider.get_authorization_token('https://one.example.com').resume).to eq('one_token')
      expect(provider.get_authorization_token('https://two.example.com').resume).to eq('two_token')
      expect(provider.get_authorization_token('https://one.example.com').resume).to eq('one_token')

      expect(context).to have_received(:get_token).twice
    end

    it 'does not mutate explicitly configured scopes' do
      configured_scopes = ['https://resource.example.com/.default']
      explicit_provider = described_class.new(context, allowed_hosts, configured_scopes)

      expect(explicit_provider.scopes).to eq(configured_scopes)
      expect(explicit_provider.scopes).not_to equal(configured_scopes)
      explicit_provider.get_authorization_token('https://one.example.com').resume

      expect(explicit_provider.scopes).to eq(configured_scopes)
      expect(configured_scopes).to eq(['https://resource.example.com/.default'])
      expect(context).to have_received(:initialize_scopes).with(configured_scopes)
    end
  end

  it 'leaves a request to a host outside the allowed hosts without an authorization header' do
    authentication_provider = MicrosoftKiotaAuthenticationOAuth::OAuthAuthenticationProvider.new(
      context, allowed_hosts, ['https://api.example.com/.default']
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'https://other.example.com'

    authentication_provider.authenticate_request(request).resume

    expect(request.headers.get_all).not_to have_key('Authorization')
    expect(context).not_to have_received(:get_token)
  end
end
