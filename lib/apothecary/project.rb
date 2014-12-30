require 'fileutils'
require 'apothecary/session'
require 'apothecary/environment'
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
      FileUtils.mkdir_p contexts_path
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

    def default_session
      @default_session ||= Session.new 'default', self
    end

    def sessions_path
      @sessions_path ||= File.join(path, 'sessions')
    end

    # ===== CONTEXTS ===================================================================================================

    def contexts_path
      File.join(path, 'contexts')
    end

    def context_names
      Dir[File.join(contexts_path, "*")].find_all { |directory_path| File.directory?(directory_path) }
                                        .map { |directory_path| File.basename(directory_path) }
    end

    def variant_path_for_context(context_or_variant_name)
      context_directory, variant_name = File.split context_or_variant_name
      if context_directory == '.'
        context_directory = context_or_variant_name
        variant_name = 'default'
      end

      variant_filename =
          if variant_name.end_with? '.yaml'
            variant_name
          else
            "#{variant_name}.yaml"
          end

      File.join(contexts_path, context_directory, variant_filename)
    end

    def variables_for_context(context_or_variant_name)
      variant_path = variant_path_for_context(context_or_variant_name)
      if File.exists?(variant_path)
        YAML.load(File.read(variant_path))
      else
        {}
      end
    end

    # ----- WRITING ----------------------------------------------------------------------------------------------------

    def write_context_yaml(context_name, context_yaml)
      variant_path = variant_path_for_context(context_name)

      # ensure directory exists
      context_dir = File.dirname variant_path
      FileUtils.mkdir_p(context_dir)

      File.open(variant_path, 'w') { |file| file << context_yaml }
      context_yaml
    end

    # ===== ENVIRONMENTS ===============================================================================================

    def default_environment
      Environment.new(default_environment_variables)
    end

    def environment_with_contexts(contexts)
      Environment.new(environment_variables_with_contexts(contexts))
    end

    def default_environment_variables
      variables = {}
      context_names.each do |context_name|
        variables.merge!(variables_for_context(context_name))
      end
      variables
    end

    def environment_variables_with_contexts(context_names)
      variables = default_environment_variables
      context_names.each do |context_name|
        variables.merge!(variables_for_context(context_name))
      end
      variables
    end

  end
end