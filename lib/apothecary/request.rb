require 'curb'
require 'json'

module Apothecary
  class Request

    UNINTERPOLATED_KEYS = %w[outputs]

    attr_reader :path
    attr_reader :request_uri
    attr_reader :data

    def initialize(path, request_uri, data = {})
      @path = path
      @request_uri = request_uri
      @data = data
    end

    def id
      File.basename(path).to_i
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

    def request_dump_path
      File.join(path, "request.txt") unless path.nil?
    end

    def response_dump_path
      File.join(path, "response.txt") unless path.nil?
    end

    def data_dump_path
      File.join(path, "data.yaml") unless path.nil?
    end

    def send!
      unless path.nil?
        FileUtils.mkdir_p(path)
        File.open(data_dump_path, 'w') { |f| f << YAML.dump(data)}
      end

      curl = Curl::Easy.new(request_uri.to_s)
      curl.headers = request_headers
      unless path.nil?
        curl.on_debug do |type, data|
          if type == Curl::CURLINFO_HEADER_OUT || type == Curl::CURLINFO_DATA_OUT
            File.open(request_dump_path, 'a') do |f|
              f << data
            end
          elsif type == Curl::CURLINFO_HEADER_IN || type == Curl::CURLINFO_DATA_IN
            File.open(response_dump_path, 'a') do |f|
              f << data
            end
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
      @response_headers = Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]
      @response_body = curl.body_str
    end

    # ===== RESPONSE ===================================================================================================

    # ----- HEADERS ----------------------------------------------------------------------------------------------------

    attr_reader :response_headers

    def content_length
      (response_headers['Content-Length'] || '0').to_i
    end

    def response_content_type
      response_headers['Content-Type']
    end

    def response_is_json?
      response_content_type && (response_content_type == 'application/json' || response_content_type.end_with?('+json'))
    end

    # ----- BODY -------------------------------------------------------------------------------------------------------

    attr_reader :response_body

    def response_json
      JSON.parse(response_body) if response_is_json?
    end

    # ===== OUTPUT =====================================================================================================

    def output(*parent_contexts)
      request_context = Context.new(response_json,
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

  end
end