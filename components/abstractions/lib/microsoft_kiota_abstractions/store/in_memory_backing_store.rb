# frozen_string_literal: true

require 'securerandom'
require_relative 'backing_store'
require_relative 'backed_model'

module MicrosoftKiotaAbstractions
  # A backing store that keeps the values in memory
  class InMemoryBackingStore
    include BackingStore

    # changed: set after initialization completed; collection_size: the length of a collection when it was set
    Entry = Struct.new(:changed, :value, :collection_size)

    attr_reader :initialization_completed
    attr_accessor :return_only_changed_values

    def initialize
      @store = {}
      @subscriptions = {}
      @initialization_completed = true
      @return_only_changed_values = false
    end

    def initialization_completed=(value)
      @initialization_completed = value
      @store.each_key do |key|
        each_backed_model(@store[key].value) { |model| model.backing_store.initialization_completed = value }
        ensure_collection_size_is_consistent(key, @store[key])
        @store[key].changed = !value
      end
    end

    def get(key)
      raise ArgumentError, 'key cannot be nil or empty' if key.nil? || key.empty?

      return unless @store.key?(key)

      ensure_collection_size_is_consistent(key, @store[key])
      entry = @store[key]
      entry.value if !@return_only_changed_values || entry.changed
    end

    def set(key, value)
      raise ArgumentError, 'key cannot be nil or empty' if key.nil? || key.empty?

      old_value = @store[key]&.value
      subscribe_to(key, value) unless @store.key?(key) && old_value.equal?(value)
      @store[key] = Entry.new(@initialization_completed, value, value.is_a?(Array) ? value.size : nil)
      @subscriptions.each_value { |callback| callback.call(key, old_value, value) }
    end

    def enumerate
      @store.each { |key, entry| ensure_collection_size_is_consistent(key, entry) } if @return_only_changed_values
      @store.select { |_, entry| !@return_only_changed_values || entry.changed }.map { |key, entry| [key, entry.value] }
    end

    def enumerate_keys_for_values_changed_to_nil
      @store.select { |_, entry| entry.changed && entry.value.nil? }.keys
    end

    def subscribe(callback, subscription_id = nil)
      raise ArgumentError, 'callback cannot be nil' if callback.nil?

      subscription_id ||= SecureRandom.uuid
      @subscriptions[subscription_id] = callback
      subscription_id
    end

    def unsubscribe(subscription_id)
      @subscriptions.delete(subscription_id)
    end

    def clear
      @store.clear
    end

    private

    def each_backed_model(value, &)
      models = value.is_a?(Array) ? value : [value]
      models.select { |model| model.is_a?(BackedModel) && model.backing_store }.each(&)
    end

    # a change inside a nested model marks the property holding it as changed
    def subscribe_to(key, value)
      each_backed_model(value) do |model|
        model.backing_store.initialization_completed = true
        model.backing_store.subscribe(->(_k, _old, _new) { set(key, value) })
      end
    end

    # an item added to or removed from a stored collection, or a change inside a nested model, marks it as changed
    def ensure_collection_size_is_consistent(key, entry)
      each_backed_model(entry.value) { |model| model.backing_store.enumerate.map(&:first).each { |k| model.backing_store.get(k) } }
      set(key, entry.value) if entry.value.is_a?(Array) && entry.value.size != entry.collection_size
    end
  end
end
