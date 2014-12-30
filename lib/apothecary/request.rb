require 'curb'
require 'json'

module Apothecary
  class Request

    attr_reader :identifier
    attr_reader :name
    attr_reader :request_uri
    attr_reader :data
    attr_reader :requests_path

    def initialize(identifier, name, request_uri, data, requests_path)
      @identifier = identifier
      @name = name
      @request_uri = request_uri
      @data = data
      @requests_path = requests_path
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
      request_part = name.gsub(/\W/, '-')
      File.join(requests_path, "#{identifier}-Request-#{request_part}.txt")
    end

    def response_dump_path
      request_part = name.gsub(/\W/, '-')
      File.join(requests_path, "#{identifier}-Response-#{request_part}.txt")
    end

    def send!
      FileUtils.mkdir_p(requests_path)

      curl = Curl::Easy.new(request_uri.to_s)
      curl.headers = request_headers
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
    end

    attr_reader :response_headers

    def content_length
      (response_headers['Content-Length'] || '0').to_i
    end

  end
end