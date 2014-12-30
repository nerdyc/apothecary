module Apothecary
  class Context

    def initialize(variables, parent_contexts = [])
      @variables = variables || {}
      @parent_contexts = parent_contexts
    end

    attr_reader :variables
    attr_reader :parent_contexts

    def has_variable?(variable_name)
      variables.has_key?(variable_name) || parent_contexts.any? { |ctx| ctx.has_variable?(variable_name) }
    end

    # ===== INTERPOLATION ==============================================================================================

    def evaluate(expression)
      first_identifier, *other_identifiers = expression.split('.')
      other_identifiers.reduce(resolve(first_identifier)) { |value, identifier| value[identifier] unless value.nil? }
    end

    INTERPOLATION_REGEX_FULL_STRING = /^\{\{((\w+)(\.\w+)*)\}\}$/
    INTERPOLATION_REGEX = /\{\{((\w+)(\.\w+)*)\}\}/

    def interpolate(value)
      if value.kind_of? String
        if value =~ INTERPOLATION_REGEX_FULL_STRING
          evaluate($1)
        else
          value.gsub(INTERPOLATION_REGEX) { evaluate($1) }
        end
      elsif value.kind_of? Hash
        interpolated = {}
        value.each do |key, value|
          interpolated[key] = interpolate(value)
        end
        interpolated
      elsif value.kind_of? Array
        value.collect { |value| interpolate(value) }
      else
        value
      end
    end

    def resolve(identifier)
      return variables[identifier] if variables.has_key?(identifier)

      # look in parent contexts
      @parent_contexts.each do |context|
        return context.resolve(identifier) if context.has_variable?(identifier)
      end

      # not found anywhere
      nil
    end

  end
end