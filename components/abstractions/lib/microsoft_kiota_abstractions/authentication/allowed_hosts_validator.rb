# frozen_string_literal: true

require 'uri'

module MicrosoftKiotaAbstractions
  # Maintains a list of valid hosts and allows authentication providers to check whether
  # a host is valid before authenticating a request
  class AllowedHostsValidator
    # creates a new AllocatedHostsValidator with provided values
    def initialize(allowed_hosts)
      self.allowed_hosts = allowed_hosts
    end

    # sets the list of valid hosts with provided value (val)
    def allowed_hosts=(val)
      hosts = {}
      val.each do |host|
        raise ArgumentError, "host should not contain http or https prefix: #{host}" if host.match?(%r{\Ahttps?://}i)

        hosts[host.downcase] = true
      end
      @allowed_hosts = hosts
    end

    # checks whether the provided host is valid
    def url_host_valid?(url)
      return false if url.nil?
      return true if @allowed_hosts.empty?

      parsed_url = URI(url)
      return false if parsed_url.host.nil?

      hostname = parsed_url.host.downcase
      return true if @allowed_hosts.key?(hostname)

      stripped_host = hostname.delete_prefix('[').delete_suffix(']')
      return true if @allowed_hosts.key?(stripped_host)

      @allowed_hosts.any? { |allowed_host, _| allowed_host.start_with?('.') && hostname.end_with?(allowed_host) }
    rescue URI::InvalidURIError, ArgumentError
      false
    end

    # gets the list of valid hosts
    attr_reader :allowed_hosts
  end
end
