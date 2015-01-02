module Apothecary
  class Action

    def initialize(data)
      @data = data
    end

    attr_reader :data

    def title
      data['title'] || data['action_name']
    end

    # ===== INTERPOLATION ==============================================================================================

    UNINTERPOLATED_KEYS = %w[outputs title action_name]

    def self.interpolate_data(action_data, context)
      request_data = context.interpolate(action_data.reject { |key| UNINTERPOLATED_KEYS.include?(key.to_s) })
      action_data.merge(request_data)
    end

    def build_request_data!(context)
      Action.interpolate_data(data, context)
    end

  end
end