# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  class ParseNodeHelper
    def self.merge_deserializers_for_intersection_wrapper(*targets)
      result = {}
      targets.each do |target|
        next if target.nil?

        # a field that several targets declare belongs to each of them
        result.merge!(target.get_field_deserializers) do |_, earlier, later|
          lambda do |node|
            earlier.call(node)
            later.call(node)
          end
        end
      end
      result
    end
  end
end
