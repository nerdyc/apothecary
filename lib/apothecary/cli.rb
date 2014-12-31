require 'thor'
require 'apothecary'
require 'json'
require 'rack'
require 'apothecary/web'

module Apothecary
  class CLI < Thor

    # ===== REQUESTS ===================================================================================================

    desc 'requests', 'List all requests defined in the project.'
    def requests
      puts "# Requests"
      puts

      project.request_names.sort.each do |request_name|
        puts "* #{request_name}"
      end
    end

    desc 'request ENDPOINT_NAME', 'Make a request to an endpoint'
    def request(request_name)
      project.default_session.perform_request!(request_name)
    end

    desc 'interpolate_request ENDPOINT_NAME', 'Prints request meta-data used to make a request'
    def interpolate_request(request_name)
      request_data = project.default_session.interpolate_request!(request_name)

      puts JSON.pretty_generate(request_data)
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

    # ===== SERVER =====================================================================================================

    desc 'server', 'Starts the Apothecary web-server interface'
    def server
      Rack::Handler::WEBrick.run Apothecary::WebApp
    end

    # ===== PROJECT ====================================================================================================

    class_option 'project', desc: 'Path to the project. Defaults to current directory.'

    protected

    def project
      @project ||= Project.new(options[:project] || Dir.pwd)
    end

  end
end