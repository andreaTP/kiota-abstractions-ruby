# frozen_string_literal: true

require_relative 'serialization/parsable'
module MicrosoftKiotaAbstractions
  class ApiError < StandardError
    include MicrosoftKiotaAbstractions::Parsable

    # the status code and headers of the response the error was raised for
    attr_accessor :response_status_code, :response_headers

    def initialize(message = nil, response_status_code: nil, response_headers: nil)
      super(message)
      @response_status_code = response_status_code
      @response_headers = response_headers
    end

    ##
    ## The deserialization information for the current model
    ## @return a i_dictionary
    ##
    def get_field_deserializers
      {}
    end

    ##
    ## Serializes information the current object
    ## @param writer Serialization writer to use to serialize this model
    ## @return a void
    ##
    def serialize(writer)
      raise StandardError, 'writer cannot be null' if writer.nil?
    end
  end
end
