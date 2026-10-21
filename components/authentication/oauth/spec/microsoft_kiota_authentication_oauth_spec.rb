# frozen_string_literal: true

require 'uri'
require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaAuthenticationOAuth do
  it '(client credential context) throws when tenant_id/client_secret is nil/empty' do
    expect do
      MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(nil, nil, nil, {})
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', 'client_secret',
                                                                     {})
    end.not_to raise_error
    expect do
      MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('', 'client_id', 'client_secret',
                                                                     {})
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', '', 'client_secret',
                                                                     {})
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', '',
                                                                     {})
    end.to raise_error(StandardError)
  end

  it '(auth code context) throws when tenant_id/client_secret is nil/empty' do
    expect do
      MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new(nil, nil, nil, nil)
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new('tenant_id', 'client_id', 'client_secret',
                                                                      'redirect_uri')
    end.not_to raise_error
    expect do
      MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new('', 'client_id', 'client_secret', 'redirect_uri',
                                                                      'code')
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new('tenant_id', '', 'client_secret',
                                                                      '')
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new('tenant_id', 'client_id', '',
                                                                      'redirect_uri')
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new('tenant_id', '', 'client_secret',
                                                                      'redirect_uri')
    end.to raise_error(StandardError)
  end

  it '(on behalf of) throws when tenant_id/client_secret is nil/empty' do
    expect do
      MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new(nil, nil, nil, nil)
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new('tenant_id', 'client_id', 'client_secret',
                                                               'assertion')
    end.not_to raise_error
    expect do
      MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new('', 'client_id', 'client_secret',
                                                               'assertion')
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new('tenant_id', '', 'client_secret',
                                                               'assertion')
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new('tenant_id', 'client_id', '',
                                                               'assertion')
    end.to raise_error(StandardError)
    expect do
      MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new('tenant_id', 'client_id', 'client_secret',
                                                               '')
    end.to raise_error(StandardError)
  end

  it 'throws when OAuthContext is used, but a custom flow is not implemented' do
    expect { MicrosoftKiotaAuthenticationOAuth::OAuthContext.get_token }.to raise_error(NoMethodError)
  end

  it 'recognizes contexts as an OAuthContext' do
    expect(MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', 'client_secret',
                                                                          {}).is_a?(MicrosoftKiotaAuthenticationOAuth::OAuthContext)).to eq(true)
    expect(MicrosoftKiotaAuthenticationOAuth::OnBehalfOfContext.new('tenant_id', 'client_id', 'client_secret',
                                                                    'assertion').is_a?(MicrosoftKiotaAuthenticationOAuth::OAuthContext)).to eq(true)
    expect(MicrosoftKiotaAuthenticationOAuth::AuthorizationCodeContext.new('tenant_id', 'client_id', 'client_secret',
                                                                           'redirect_uri').is_a?(MicrosoftKiotaAuthenticationOAuth::OAuthContext)).to eq(true)
  end

  it 'returns a fiber resolving to nil when uri is nil or invalid for allowed hosts' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, ['graph.microsoft.com'])

    fiber_nil = provider.get_authorization_token(nil)
    expect(fiber_nil).to be_a(Fiber)
    expect(fiber_nil.resume).to be_nil

    fiber_untrusted = provider.get_authorization_token('https://untrusted.com/v1.0')
    expect(fiber_untrusted).to be_a(Fiber)
    expect(fiber_untrusted.resume).to be_nil
  end

  it 'allows http on localhost and loopback addresses with empty or explicit allowed hosts' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    allow(context).to receive(:get_token).and_return(double('token', to_hash: {}, token: 'test_token'))

    ['http://localhost:8080/v1.0', 'http://127.0.0.1:8080/v1.0', 'http://[::1]:8080/v1.0'].each do |url|
      # Test with default/empty allowed hosts
      provider_empty = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, [])
      fiber_empty = provider_empty.get_authorization_token(url)
      expect(fiber_empty).to be_a(Fiber)
      expect(fiber_empty.resume).to eq('test_token')

      # Test with explicitly allowed host
      host = URI(url).hostname || URI(url).host
      provider_explicit = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, [host])
      fiber_explicit = provider_explicit.get_authorization_token(url)
      expect(fiber_explicit).to be_a(Fiber)
      expect(fiber_explicit.resume).to eq('test_token')
    end
  end

  it 'raises error for unsupported schemes even on localhost' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, [])

    ['ftp://localhost:8080/v1.0', 'ws://localhost:8080/v1.0', '//localhost:8080/v1.0'].each do |url|
      expect do
        provider.get_authorization_token(url)
      end.to raise_error(StandardError, 'Only https is supported')
    end
  end

  it 'raises error for non-https on non-localhost hosts' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, ['graph.microsoft.com'])

    expect do
      provider.get_authorization_token('http://graph.microsoft.com/v1.0')
    end.to raise_error(StandardError, 'Only https is supported')
  end

  it 'leaves request unauthenticated when host is not allowed via OAuthAuthenticationProvider' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    auth_provider = MicrosoftKiotaAuthenticationOAuth::OAuthAuthenticationProvider.new(
      context, ['graph.microsoft.com'], []
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'https://untrusted.com/v1.0'

    expect { auth_provider.authenticate_request(request).resume }.not_to raise_error
    expect(request.headers.get_all.key?('Authorization')).to be(false)
  end

  it 'authenticates http localhost request via OAuthAuthenticationProvider' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    allow(context).to receive(:get_token).and_return(double('token', to_hash: {}, token: 'test_token'))

    auth_provider = MicrosoftKiotaAuthenticationOAuth::OAuthAuthenticationProvider.new(
      context, ['localhost'], []
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'http://localhost:8080/v1.0'

    auth_provider.authenticate_request(request).resume
    expect(request.headers.get('Authorization').first).to eq('Bearer test_token')
  end
end
