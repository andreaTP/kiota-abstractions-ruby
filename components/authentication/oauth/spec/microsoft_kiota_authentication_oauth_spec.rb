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

  it 'returns nil when uri is nil or invalid for allowed hosts' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, ['graph.microsoft.com'])

    expect(provider.get_authorization_token(nil)).to be_nil
    expect(provider.get_authorization_token('https://untrusted.com/v1.0')).to be_nil
  end

  it 'allows http on localhost and loopback addresses' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    allow(context).to receive(:get_token).and_return(double('token', to_hash: {}, token: 'test_token'))

    ['http://localhost:8080/v1.0', 'http://127.0.0.1:8080/v1.0', 'http://[::1]:8080/v1.0'].each do |url|
      provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, [])
      fiber = provider.get_authorization_token(url)
      expect(fiber).to be_a(Fiber)
      expect(fiber.resume).to eq('test_token')
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
end
