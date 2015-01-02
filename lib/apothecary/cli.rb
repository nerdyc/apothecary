require 'thor'
require 'apothecary'
require 'json'
require 'rack'
require 'apothecary/web'

module Apothecary
  class CLI < Thor

    # ===== ACTIONS ====================================================================================================

    desc 'actions', 'List all actions defined in the project.'
    def actions
      puts "# Actions"
      puts

      project.action_names.sort.each do |action_name|
        puts "* #{action_name}"
      end
    end

    desc 'request ACTION_NAME', 'Makes a request'
    option :session, :default => "default"
    def request(action_name)
      session.perform_request!(action_name)
    end

    desc 'build-request ACTION_NAME', "Prints meta-data used to make a request, but doesn't make the request"
    option :session, :default => "default"
    def build_request(action_name)
      request_data = session.build_request_data!(action_name)
      puts JSON.pretty_generate(request_data)
    end

    desc 'list-requests', "Lists requests made within a session"
    option :session, :default => "default"
    def list_requests
      puts "# Session Requests"
      puts
      session.request_identifiers.each do |request_identifier|
        puts "* #{request_identifier}"
      end
      puts
    end

    # ===== SESSIONS ===================================================================================================

    desc 'sessions', 'List sessions in the project'
    def sessions
      puts "# Sessions"
      puts

      project.session_names.sort.each do |session_name|
        puts "* #{session_name}"
      end
    end

    desc 'create-session SESSION-NAME environments', "Create a session"
    def create_session(session_name, *env_names)
      session = project.create_session(session_name, *env_names)

      puts "Created session at #{session.directory_path}"
    end

    # ===== SERVER =====================================================================================================

    desc 'server', 'Starts the Apothecary web-server interface'
    def server
      Apothecary::WebApp.project_path = project_path
      Rack::Handler::WEBrick.run Apothecary::WebApp
    end

    # ===== PROJECT ====================================================================================================

    class_option 'project', desc: 'Path to the project. Defaults to current directory.'

    protected

    def project_path
      options[:project] || Dir.pwd
    end

    def project
      @project ||= Project.new(project_path)
    end

    def session
      @session =
          if options[:session] == 'default' && !project.session_names.include?('default')
            project.create_session('default')
          else
            project.open_session(options[:session])
          end
    end

  end
end