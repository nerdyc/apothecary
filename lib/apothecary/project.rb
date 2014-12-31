require 'fileutils'
require 'apothecary/session'
require 'yaml'
require 'pathname'

module Apothecary

  #
  # Represents an Apothecary project directory and its contents.
  #
  class Project

    def initialize(path)
      @path = File.expand_path(path)
    end

    # ===== PATH =======================================================================================================

    attr_reader :path

    def create_skeleton
      FileUtils.mkdir_p path
      FileUtils.mkdir_p requests_path
      FileUtils.mkdir_p environments_path
      FileUtils.mkdir_p sessions_path
    end

    # ===== REQUESTS ===================================================================================================

    def requests_path
      @requests_path ||= File.join(path, "requests")
    end

    def request_paths
      Dir[File.join(requests_path, "**/*.yaml")]
    end

    def request_names
      requests_path = Pathname(self.requests_path)
      request_paths.map { |request_path|
        Pathname(request_path).relative_path_from(requests_path).to_s.sub(/\.yaml$/, '')
      }
    end

    def request_named(request_name)
      request_file_path = request_file_path_from_name(request_name)
      if File.exists? request_file_path
        YAML.load(File.read(request_file_path))
      end
    end

    def request_named!(request_name)
      request_named(request_name) || raise("Unknown request: #{request_name}")
    end

    # ----- WRITING ----------------------------------------------------------------------------------------------------

    def request_file_path_from_name(request_name)
      request_filename = request_name
      unless request_filename.end_with? ".yaml"
        request_filename = "#{request_filename}.yaml"
      end

      File.join(requests_path, request_filename)
    end

    def write_request_yaml(request_name, request_yaml)
      request_path = request_file_path_from_name(request_name)

      FileUtils.mkdir_p(File.dirname(request_path))
      File.open(request_path, 'w') { |file| file << request_yaml }

      request_yaml
    end

    # ===== SESSIONS ===================================================================================================

    def create_session(name, options = {})
      environment_names = (options['environments'] || options[:environments] || [])
      variables = (options['variables'] || options[:variables] || {})

      session = Session.new(File.join(sessions_path, name),
                            self,
                            environment_names,
                            variables)
      session.save!
      session
    end

    def open_session(name)
      session_path = File.join(sessions_path, name)
      Session.load!(session_path, self)
    end

    def default_session
      @default_session ||= Session.new(File.join(sessions_path, 'default'), self, [], {})
    end

    def sessions_path
      @sessions_path ||= File.join(path, 'sessions')
    end

    def session_with_environments(*environments)
      environments.flatten!

      Session.new(nil, self, environments, {})
    end

    def session_with_variables(variables)
      Session.new(nil, self, [], variables)
    end

    # ===== ENVIRONMENTS ===============================================================================================

    def environments_path
      File.join(path, 'environments')
    end

    def environment_names
      Dir[File.join(environments_path, "*")].find_all { |directory_path| File.directory?(directory_path) }
                                            .map { |directory_path| File.basename(directory_path) }
    end

    def variant_path_for_environment(env_or_variant_name)
      env_directory, variant_name = File.split env_or_variant_name
      if env_directory == '.'
        env_directory = env_or_variant_name
        variant_name = 'default'
      end

      variant_filename =
          if variant_name.end_with? '.yaml'
            variant_name
          else
            "#{variant_name}.yaml"
          end

      File.join(environments_path, env_directory, variant_filename)
    end

    def variables_for_environment(environment_or_variant_name)
      variant_path = variant_path_for_environment(environment_or_variant_name)
      if File.exists?(variant_path)
        YAML.load(File.read(variant_path))
      else
        {}
      end
    end

    # ----- WRITING ----------------------------------------------------------------------------------------------------

    def write_environment_yaml(environment_name, environment_yaml)
      variant_path = variant_path_for_environment(environment_name)

      # ensure directory exists
      env_dir = File.dirname variant_path
      FileUtils.mkdir_p(env_dir)

      File.open(variant_path, 'w') { |file| file << environment_yaml }
      environment_yaml
    end

    # ===== FLOWS ======================================================================================================

    def flows_path
      File.join(path, 'flows')
    end

    def flow_file_path_from_name(flow_name)
      flow_filename = flow_name
      unless flow_filename.end_with? ".yaml"
        flow_filename = "#{flow_filename}.yaml"
      end

      File.join(flows_path, flow_filename)
    end

    def flow_named(flow_name)
      flow_file_path = flow_file_path_from_name(flow_name)
      if File.exists? flow_file_path
        YAML.load(File.read(flow_file_path))
      end
    end

    def flow_named!(flow_name)
      flow_named(flow_name) || raise("Unknown flow: #{flow_name}")
    end


    def write_flow_yaml(flow_name, flow_yaml)
      flow_path = flow_file_path_from_name(flow_name)

      FileUtils.mkdir_p(File.dirname(flow_path))
      File.open(flow_path, 'w') { |file| file << flow_yaml }

      flow_yaml
    end

  end

end