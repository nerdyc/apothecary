module Apothecary
  class Action

    def initialize(data)
      @data = data
    end

    attr_reader :data

    def title
      data['title'] || data['action_name']
    end

  end
end