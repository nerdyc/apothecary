require 'fileutils'
require 'apothecary/request'
require 'apothecary/context'
require 'apothecary/action'

module Apothecary
  class Session < Context

    def initialize(directory_path, project, title, env_names, variables)
      parent_contexts = []
      (env_names + project.environment_names).uniq.each do |environment_name|
        parent_context = Context.new(project.variables_for_environment(environment_name))
        parent_contexts << parent_context
      end

      super(variables, parent_contexts)

      @directory_path = directory_path
      @project = project
      @title = title
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

    def title
      @title || name
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
      File.open(configuration_path, 'w') { |f| f << YAML.dump('title' => title,
                                                              'environments' => environment_names,
                                                              'variables' => variables) }
    end

    def self.load!(directory_path, project)
      raise "Session not found at path: #{directory_path}" unless File.directory?(directory_path)

      config_path = File.join(directory_path, 'config.yaml')
      environment_names = []
      variables = {}
      title = nil
      if File.exists?(config_path)
        configuration = YAML.load_file config_path
        title = configuration['title']
        environment_names = configuration['environments']
        variables = configuration['variables']
      end

      Session.new(directory_path, project, title, environment_names, variables)
    end

    # ===== URI ========================================================================================================

    def base_url
      Request.uri_from_value(resolve('base_url'))
    end

    def resolve_uri(uri)
      uri_value = Request.uri_from_value(uri)

      base_url_value = base_url
      unless base_url_value.nil?
        uri_value = URI.join(base_url_value, uri_value)
      end

      uri_value
    end

    # ===== REQUESTS ===================================================================================================

    def requests_path
      @requests_path ||= File.join(directory_path, 'requests')
    end

    def request_identifiers
      Dir[File.join(requests_path, '*')].select { |request_path| File.directory?(request_path) }
                                        .map { |request_path| File.basename(request_path) }
    end

    def request_with_identifier(request_identifier)
      Request.new(File.join(requests_path, request_identifier))
    end

    def request_count
      request_identifiers.count
    end

    def last_request_identifier
      request_identifiers.max_by { |request_identifier| request_identifier.to_i }
    end

    def next_request_number
      (last_request_identifier || '0').to_i + 1
    end

    def build_request_data!(action_name_or_data, options = {})
      action =
          if action_name_or_data.kind_of? Hash
            Action.new(action_name_or_data)
          else
            project.action_named!(action_name_or_data)
          end

      parent_contexts = (options[:environments] || []).collect { |env_name|
        Context.new(project.variables_for_environment(env_name))
      }
      parent_contexts << self

      context = Context.new(options[:variables] || {},
                            parent_contexts)

      action.build_request_data!(context)
    end

    def build_request!(action_name_or_data, options = {})
      request_data = build_request_data!(action_name_or_data, options)
      request_data['base_url'] ||= resolve('base_url')

      request_path =
        if action_name_or_data.kind_of? String
          File.join(requests_path, "#{next_request_number}_#{action_name_or_data.gsub(/\W/, '_')}")
        end

      Request.new(request_path, request_data)
    end

    def perform_request!(action_name_or_data, options = {})
      request = build_request!(action_name_or_data, options)
      request.send!

      output = request.output(self)
      if output
        variables.merge!(output)
      end
      save!

      request
    end

    # ===== FLOWS ======================================================================================================

    def perform_flow!(flow_name)
      flow_data = project.flow_named!(flow_name)
      flow_data['actions'].each do |action_name_or_data|
        perform_request!(action_name_or_data)
      end
    end

  end
end