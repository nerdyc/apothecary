require 'fileutils'
require 'apothecary/session'
require 'apothecary/action'
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

    def name
      File.basename(path)
    end

    # ===== ACTIONS ====================================================================================================

    def actions_path
      @actions_path ||= File.join(path, "actions")
    end

    def action_paths
      Dir[File.join(actions_path, "**/*.yaml")]
    end

    def action_names
      actions_path = Pathname(self.actions_path)
      action_paths.map { |action_path|
        Pathname(action_path).relative_path_from(actions_path).to_s.sub(/\.yaml$/, '')
      }.sort
    end

    def action_data_named(action_name)
      action_file_path = action_file_path_from_name(action_name)
      if File.exists? action_file_path
        YAML.load_file(action_file_path).merge('action_name' => action_name)
      end
    end

    def action_data_named!(action_name)
      action_data_named(action_name) || raise("Unknown action: #{action_name}")
    end

    def action_named!(action_name)
      Action.new(action_data_named!(action_name).merge('action_name' => action_name))
    end

    # ----- WRITING ----------------------------------------------------------------------------------------------------

    def action_file_path_from_name(action_name)
      action_filename = action_name
      unless action_filename.end_with? ".yaml"
        action_filename = "#{action_filename}.yaml"
      end

      File.join(actions_path, action_filename)
    end

    def write_action_yaml(action_name, action_yaml)
      action_path = action_file_path_from_name(action_name)

      FileUtils.mkdir_p(File.dirname(action_path))
      File.open(action_path, 'w') { |file| file << action_yaml }

      action_yaml
    end

    # ===== SESSIONS ===================================================================================================

    def create_session(name, options = {})
      environment_names = (options['environments'] || options[:environments] || [])
      variables = (options['variables'] || options[:variables] || {})

      session = Session.new(File.join(sessions_path, name),
                            self,
                            options['title'] || options[:title],
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
      @default_session ||= Session.new(File.join(sessions_path, 'default'), self, "Default Session", [], {})
    end

    def sessions_path
      @sessions_path ||= File.join(path, 'sessions')
    end

    def session_with_environments(*environments)
      environments.flatten!

      Session.new(nil, self, nil, environments, {})
    end

    def session_with_variables(variables)
      Session.new(nil, self, nil, [], variables)
    end

    def session_names
      Dir[File.join(sessions_path, '*')].select { |session_path| File.directory?(session_path) }
                                        .map { |session_path| File.basename(session_path) }
    end

    # ===== ENVIRONMENTS ===============================================================================================

    def environments_path
      File.join(path, 'environments')
    end

    def environment_names
      Dir[File.join(environments_path, "*")].find_all { |directory_path| File.directory?(directory_path) }
                                            .map { |directory_path| File.basename(directory_path) }
    end

    def variants_of_environment(environment_name)
      Dir[File.join(environments_path, environment_name, "*.yaml")].map { |directory_path| File.basename(directory_path, ".yaml") }
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
        YAML.load_file variant_path
      else
        {}
      end
    end

    def create_environment(name, variables = {})
      write_environment_yaml(name, YAML.dump(variables))

      variables
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
        YAML.load_file flow_file_path
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