require 'fileutils'
require 'apothecary/request'

module Apothecary
  class Session

    def initialize(name, project)
      @name = name
      @project = project
      @requests = []
    end

    # ===== PROJECT ====================================================================================================

    attr_reader :project

    # ===== NAME =======================================================================================================

    attr_reader :name

    # ===== ENVIRONMENT ================================================================================================

    def environment
      project.default_environment
    end
    alias env environment

    # ===== REQUESTS ===================================================================================================

    attr_reader :requests

    def request_count
      requests.count
    end

    def interpolate_request!(request_name)
      request_data =
          if request_name.kind_of? Hash
            request_name
          else
            project.request_named!(request_name)
          end

      environment.interpolate(request_data)
    end

    def build_request!(request_name)
      interpolated_data = interpolate_request!(request_name)

      uri = environment.resolve_uri(interpolated_data)

      Request.new((request_count+1).to_s,
                  request_name,
                  uri,
                  interpolated_data,
                  requests_path)
    end

    def perform_request!(request_name)
      request = build_request!(request_name)
      request.send!

      @requests << request
    end

    def total_received
      requests.inject(0) { |total_received, response| total_received + response.content_length }
    end

    def directory_path
      @directory_path ||= File.join(project.sessions_path, name)
    end

    def requests_path
      @requests_path ||= File.join(directory_path, 'requests')
    end

  end
end