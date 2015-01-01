require 'curb'
require 'json'

module Apothecary
  class Request

    attr_reader :path
    attr_reader :data

    def initialize(path, data = nil)
      @path = path
      @data = data
    end

    def identifier
      File.basename(path)
    end

    # ===== DATA =======================================================================================================
    # Inputs describing the request to perform

    def data_path
      File.join(path, "data.yaml") unless path.nil?
    end

    def data
      @data ||= YAML.load_file(data_path)
    end

    def base_url
      data['base_url']
    end

    def request_uri
      @request_uri ||= Request.uri_from_value(data)
    end

    def request_method
      (data['method'] || 'GET').to_s.upcase
    end

    def request_headers
      data['headers'] || {}
    end

    def request_json_body
      data['json_body']
    end

    def username
      data['username']
    end

    def password
      data['password']
    end

    # ===== HTTP REQUEST DATA ==========================================================================================
    # Actual data sent over HTTP

    def http_request_line
      load_http_request! if @http_request_line.nil?
      @http_request_line
    end

    def http_request_headers
      load_http_request! if @http_request_headers.nil?
      @http_request_headers
    end

    def http_request_content_type
      http_request_headers['Content-Type']
    end

    def http_request_is_json?
      self.class.content_type_is_json?(http_request_content_type)
    end

    def http_request_body
      File.read(http_request_body_path) if File.exists?(http_request_body_path)
    end

    def http_request_headers_string
      File.read(http_request_headers_path) if File.exists?(http_request_headers_path)
    end

    # ----- PATHS ------------------------------------------------------------------------------------------------------

    def http_request_headers_path
      File.join(path, "request-headers.txt") unless path.nil?
    end

    def http_request_body_path
      File.join(path, "request-body.txt") unless path.nil?
    end

    def load_http_request!
      return unless File.exists?(http_request_headers_path)

      @http_request_line, @http_request_headers = parse_headers(File.read(http_request_headers_path))
    end

    # ===== HTTP RESPONSE ==============================================================================================

    def http_response_json
      JSON.parse(http_response_body) if http_response_is_json?
    end

    def http_response_content_type
      http_response_headers['Content-Type']
    end

    def self.content_type_is_json?(content_type)
      return false if content_type.nil?
      return true if content_type =~ /^application\/json(;.*)?$/
      return true if content_type =~ /^\w+\/\w+\+json(;.*)?$/

      false
    end

    def http_response_is_json?
      self.class.content_type_is_json?(http_response_content_type)
    end

    def http_response_status_line
      load_http_response! if @http_response_status_line.nil?
      @http_response_status_line
    end

    def http_response_headers
      load_http_response! if @http_response_headers.nil?
      @http_response_headers
    end

    def load_http_response!
      return unless File.exists?(http_response_headers_path)

      @http_response_status_line, @http_response_headers = parse_headers(File.read(http_response_headers_path))
    end

    def http_response_headers_string
      File.read(http_response_headers_path) if File.exists?(http_response_headers_path)
    end

    def http_response_body
      @http_response_body ||=
          if File.exists?(http_response_body_path)
            File.read(http_response_body_path)
          end
    end

    def http_response_headers_path
      File.join(path, "response-headers.txt") unless path.nil?
    end

    def http_response_body_path
      File.join(path, "response-body.txt") unless path.nil?
    end

    # ===== HTTP HELPERS ===============================================================================================

    def parse_headers(header_str)
      http_response, *http_headers = header_str.split(/[\r\n]+/).map(&:strip)
      [http_response, Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]]
    end

    # ===== SEND =======================================================================================================

    UNINTERPOLATED_KEYS = %w[outputs]

    def send!
      unless path.nil?
        FileUtils.mkdir_p(path)
        File.open(data_path, 'w') { |f| f << YAML.dump(data)}
      end

      curl = Curl::Easy.new(request_uri.to_s)
      curl.headers = request_headers
      unless path.nil?
        curl.on_debug do |type, data|
          output_file =
            if type == Curl::CURLINFO_HEADER_OUT
              http_request_headers_path
            elsif type == Curl::CURLINFO_DATA_OUT
              http_request_body_path
            elsif type == Curl::CURLINFO_HEADER_IN
              http_response_headers_path
            elsif type == Curl::CURLINFO_DATA_IN
              http_response_body_path
            end

          unless output_file.nil?
            File.open(output_file, 'a') { |f| f << data }
          end
        end
      end

      if username != nil
        curl.username = username
        curl.password = password
      end

      http_verb = request_method
      if request_json_body
        unless request_headers.has_key? 'Content-Type'
          curl.headers['Content-Type'] = 'application/json'
        end

        json_string = JSON.generate(request_json_body)
        if http_verb == 'PUT'
          curl.put_data = json_string
          curl.http http_verb
        elsif http_verb == 'POST'
          curl.post json_string
        else
          curl.http http_verb
        end
      else
        curl.http http_verb
      end

      http_response, *http_headers = curl.header_str.split(/[\r\n]+/).map(&:strip)

      @http_response_status_line = http_response
      @http_response_headers = Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]
      @http_response_body = curl.body_str
    end

    # ===== OUTPUT =====================================================================================================

    def output(*parent_contexts)
      request_context = Context.new(http_response_json,
                                    parent_contexts.flatten)

      output_definition = data['outputs']

      if output_definition
        output_values = {}
        output_definition.each do |output_name, definition|
          output_values[output_name] = request_context.interpolate(definition)
        end
        output_values
      end
    end

    # ===== URIS =======================================================================================================

    def self.uri_from_hash(components)
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

      uri = uri_class.build(scheme: scheme,
                            host:   host,
                            port:   port,
                            path:   path)

      # resolve against any base url
      base_url = uri_from_value(components['base_url'])
      if base_url != nil
        uri = URI.join(base_url, uri)
      end

      uri
    end

    def self.uri_from_value(url_value)
      if url_value.kind_of? URI
        url_value
      elsif url_value.kind_of? Hash
        uri_from_hash(url_value)
      elsif url_value.kind_of? String
        URI(url_value)
      end
    end

  end
end