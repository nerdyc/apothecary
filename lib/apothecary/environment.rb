module Apothecary
  class Environment

    def initialize(variables)
      @variables = variables
    end

    # ===== URI ========================================================================================================

    def base_url
      uri_from_value(evaluate('base_url'))
    end

    def uri_from_hash(components)
      scheme  = components['scheme']
      host    = components['host']
      port    = components['port']
      path    = components['path']

      if host.nil?
        port = nil
      else
        scheme ||= 'https'
      end

      uri_class = URI::Generic
      if scheme == 'https'
        uri_class = URI::HTTPS
      elsif scheme == 'http'
        uri_class = URI::HTTP
      end

      uri_class.build(scheme: scheme,
                      host:   host,
                      port:   port,
                      path:   path)
    end

    def uri_from_value(url_value)
      if url_value.kind_of? URI
        url_value
      elsif url_value.kind_of? Hash
        uri_from_hash(url_value)
      elsif url_value.kind_of? String
        URI(url_value)
      end
    end

    def resolve_uri(uri)
      uri_value = uri_from_value(uri)

      base_url_value = base_url
      unless base_url_value.nil?
        uri_value = URI.join(base_url_value, uri_value)
      end

      uri_value
    end

    # ===== INTERPOLATION ==============================================================================================

    attr_reader :variables

    def evaluate(expression)
      expression.split('.').reduce(variables) { |value, identifier| value[identifier] unless value.nil? }
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

  end
end