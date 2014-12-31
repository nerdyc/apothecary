require 'fileutils'
require 'apothecary/request'
require 'apothecary/context'

module Apothecary
  class Session < Context

    def initialize(directory_path, project, env_names, variables)
      parent_contexts = []
      (env_names + project.environment_names).uniq.each do |environment_name|
        parent_context = Context.new(project.variables_for_environment(environment_name))
        parent_contexts << parent_context
      end

      super(variables, parent_contexts)

      @directory_path = directory_path
      @project = project
      @environment_names = env_names

      @requests = []
    end

    # ===== PROJECT ====================================================================================================

    attr_reader :project

    # ===== NAME =======================================================================================================

    attr_reader :directory_path

    def name
      File.basename(directory_path)
    end

    # ===== ENVIRONMENTS ===============================================================================================

    attr_reader :environment_names

    # ===== PERSISTENCE ================================================================================================

    def configuration_path
      File.join(directory_path, 'config.yaml')
    end

    def save!
      raise "Cannot save a temporary session!" if directory_path.nil?

      FileUtils.mkdir_p(directory_path)
      File.open(configuration_path, 'w') { |f| f << YAML.dump('environments' => environment_names,
                                                              'variables' => variables) }
    end

    def self.load!(directory_path, project)
      raise "Session not found at path: #{sessions_path}" unless File.directory?(directory_path)

      config_path = File.join(directory_path, 'config.yaml')
      environment_names = []
      variables = {}
      if File.exists?(config_path)
        configuration = YAML.load_file config_path
        environment_names = configuration['environments']
        variables = configuration['variables']
      end

      Session.new(directory_path, project, environment_names, variables)
    end

    # ===== URI ========================================================================================================

    def base_url
      uri_from_value(resolve('base_url'))
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

    # ===== REQUESTS ===================================================================================================

    attr_reader :requests

    def requests_path
      @requests_path ||= File.join(directory_path, 'requests')
    end

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


      interpolated_data = interpolate(request_data.reject { |key| Request::UNINTERPOLATED_KEYS.include?(key.to_s) })
      request_data.merge(interpolated_data)
    end

    def build_request!(request_name)
      interpolated_data = interpolate_request!(request_name)

      uri = resolve_uri(interpolated_data)

      Request.new((request_count+1).to_s,
                  request_name,
                  uri,
                  interpolated_data,
                  requests_path)
    end

    def perform_request!(request_name)
      request = build_request!(request_name)
      request.send!

      output = request.output(self)
      if output
        variables.merge!(output)
      end

      @requests << request
      request
    end

    def total_received
      requests.inject(0) { |total_received, response| total_received + response.content_length }
    end

    # ===== FLOWS ======================================================================================================

    def perform_flow!(flow_name)
      flow_data = project.flow_named!(flow_name)
      flow_data['requests'].each do |request_data|
        perform_request!(request_data)
      end
    end

  end
end