# frozen_string_literal: true

require 'securerandom'
require_relative 'backing_store'
require_relative 'backed_model'

module MicrosoftKiotaAbstractions
  # A backing store that keeps the values in memory
  class InMemoryBackingStore
    include BackingStore

    # changed: set after initialization completed; snapshot: a copy of a collection's items when it was set
    Entry = Struct.new(:changed, :value, :snapshot)

    attr_reader :initialization_completed
    attr_accessor :return_only_changed_values

    def initialize
      @store = {}
      @subscriptions = {}
      @member_subscriptions = {}
      @initialization_completed = true
      @return_only_changed_values = false
    end

    def initialization_completed=(value)
      @initialization_completed = value
      @store.each_key do |key|
        backed_models(@store[key].value).each { |model| model.backing_store.initialization_completed = value }
        ensure_collection_is_consistent(key)
        @store[key].changed = !value
      end
    end

    def get(key)
      validate(key)
      return unless @store.key?(key)

      ensure_collection_is_consistent(key)
      entry = @store[key]
      entry.value if !@return_only_changed_values || entry.changed
    end

    def set(key, value)
      validate(key)
      old_value = @store[key]&.value
      @store[key] = Entry.new(@initialization_completed, value, snapshot_of(value))
      follow_members(key, value)
      @subscriptions.each_value { |callback| callback.call(key, old_value, value) }
    end

    def enumerate
      @store.each_key { |key| ensure_collection_is_consistent(key) } if @return_only_changed_values
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
      @member_subscriptions.each_key.to_a.each { |key| follow_members(key, nil) }
      @store.clear
    end

    private

    def validate(key)
      raise ArgumentError, 'key cannot be nil or empty' if key.nil? || key.empty?
    end

    def backed_models(value)
      (value.is_a?(Array) ? value : [value]).select { |model| model.is_a?(BackedModel) && model.backing_store }
    end

    def snapshot_of(value)
      value.dup if value.is_a?(Array) || value.is_a?(Hash)
    end

    # the nested models a property holds report their changes to it, for as long as they are in it
    def follow_members(key, value)
      followed = @member_subscriptions[key] ||= {}.compare_by_identity
      members = backed_models(value).to_h { |model| [model, true] }.compare_by_identity
      followed.keys.reject { |model| members.key?(model) }.each { |model| model.backing_store.unsubscribe(followed.delete(model)) }
      members.each_key { |model| followed[model] ||= model.backing_store.subscribe(->(*) { member_changed(key) }) }
      @member_subscriptions.delete(key) if followed.empty?
    end

    def member_changed(key)
      entry = @store[key]
      return if entry.nil?

      entry.changed = true if @initialization_completed
      @subscriptions.each_value { |callback| callback.call(key, entry.value, entry.value) }
    end

    # a collection changed in place since it was set, or holding a changed model, is marked as changed
    def ensure_collection_is_consistent(key)
      entry = @store[key]
      backed_models(entry.value).each { |model| model.backing_store.enumerate.map(&:first).each { |k| model.backing_store.get(k) } }
      set(key, entry.value) unless entry.snapshot.nil? || entry.value == entry.snapshot
    end
  end
end
