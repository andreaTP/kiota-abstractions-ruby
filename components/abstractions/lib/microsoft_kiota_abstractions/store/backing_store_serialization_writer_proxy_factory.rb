# frozen_string_literal: true

require_relative '../serialization/serialization_writer_proxy_factory'
require_relative 'backed_model'

module MicrosoftKiotaAbstractions
  # Writes only the values of a model that changed, including the ones set back to nil
  class BackingStoreSerializationWriterProxyFactory < SerializationWriterProxyFactory
    def initialize(concrete)
      super(concrete, method(:only_changed_values), method(:all_values), method(:write_values_changed_to_nil))
    end

    private

    def backing_store_of(value)
      value.backing_store if value.is_a?(BackedModel)
    end

    def only_changed_values(value)
      backing_store_of(value)&.return_only_changed_values = true
    end

    def all_values(value)
      store = backing_store_of(value)
      return unless store

      store.return_only_changed_values = false
      store.initialization_completed = true
    end

    def write_values_changed_to_nil(value, writer)
      backing_store_of(value)&.enumerate_keys_for_values_changed_to_nil&.each { |key| writer.write_null_value(key) }
    end
  end
end
