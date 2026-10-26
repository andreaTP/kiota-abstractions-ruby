# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require 'oauth2'
require_relative 'extensions/oauth2_ext'
require_relative 'contexts/client_credential_context'
require_relative 'contexts/authorization_code_context'
require_relative 'contexts/on_behalf_of_context'
require_relative 'contexts/oauth_context'
require_relative 'contexts/oauth_custom_flow'

module MicrosoftKiotaAuthenticationOAuth
  # Access Token Provider class implementation
  class OAuthAccessTokenProvider
    LOCALHOST_STRINGS = ['localhost', '::1', '[::1]', '127.0.0.1'].freeze

    # This is the initializer for OAuthAccessTokenProvider.
    # :params
    #   token_request_context: a instance of one of our token request context or a custom implementation
    #   allowed_hosts: an array of strings, where each string is an allowed host, default is empty
    #   scopes: an array of strings, where each string is a scope, default is empty array
    def initialize(token_request_context, allowed_hosts = [], scopes = [])
      raise StandardError, 'Parameter token_request_context cannot be nil.' if token_request_context.nil?

      @token_request_context = token_request_context

      unless @token_request_context.is_a?(MicrosoftKiotaAuthenticationOAuth::OAuthContext)
        raise StandardError,
              'Parameter token_request_context must be an instance of one of our grant flow context classes.'
      end

      @cached_tokens = {}

      @host_validator = if allowed_hosts.nil? || allowed_hosts.empty?
                          MicrosoftKiotaAbstractions::AllowedHostsValidator.new([])
                        else
                          MicrosoftKiotaAbstractions::AllowedHostsValidator.new(allowed_hosts)
                        end
      @token_request_context.initialize_oauth_provider
      @scopes = if scopes.nil?
                  []
                else
                  scopes.dup
                end
    end

    # This function obtains the authorization token.
    # :params
    #   uri: a string containing the uri
    #   additional_params: hash of symbols to string values, ie { response_mode: 'fragment', prompt: 'login' }
    #                      default is empty hash
    def get_authorization_token(uri, _additional_properties = {})
      return Fiber.new { nil } if !uri || !@host_validator.url_host_valid?(uri)

      return Fiber.new { nil } if parsed_url.nil? || parsed_url.host.nil?

      https_version = parsed_url.dup
      https_version.scheme = 'https'
      return Fiber.new { nil } unless @host_validator.url_host_valid?(https_version.to_s)

      is_localhost = localhost?(parsed_url)
      is_https = parsed_url.scheme == 'https'
      is_http_localhost = parsed_url.scheme == 'http' && is_localhost
      raise StandardError, 'Only https is supported' unless is_https || is_http_localhost

      effective_scopes = @scopes.empty? ? ["#{parsed_url.scheme}://#{parsed_url.host}/.default"] : @scopes.dup
      cache_key = effective_scopes.freeze
      Fiber.new do
        @token_request_context.initialize_scopes(effective_scopes)
        token_value = nil
        cached_token = @cached_tokens[cache_key]
        unless cached_token.nil?
          token = OAuth2::AccessToken.from_hash(@token_request_context.oauth_provider, cached_token)
          if token && !token.expired?
            token_value = token.token
          elsif token
            token = token.refresh!
            @cached_tokens[cache_key] = token.to_hash
            token_value = token.token
          end
        end

        if token_value.nil?
          token = @token_request_context.get_token
          unless token.nil?
            @cached_tokens[cache_key] = token.to_hash
            token_value = token.token
          end
        end

        token_value
      end
    end

    attr_reader :scopes, :host_validator

    protected

    attr_writer :host_validator, :token_credential, :scopes, :cached_tokens
  end
end
