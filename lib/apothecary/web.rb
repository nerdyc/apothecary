require 'sinatra/base'
require 'haml'
require 'erb'

module Apothecary
  class WebApp < Sinatra::Base

    # ===== SETTINGS ===================================================================================================

    set :app_file, __FILE__
    set :root, File.expand_path('../web', __FILE__)

    # ===== PROJECT ====================================================================================================

    def self.project_path
      @project_path
    end

    def self.project_path=(project_path)
      @project_path = project_path
    end

    before do
      @project = Apothecary::Project.new(Apothecary::WebApp.project_path)
    end

    helpers do

      def project
        @project
      end

      def session
        @session
      end

    end

    # ===== ROOT =======================================================================================================

    get '/' do
      erb :index
    end

    # ===== SESSIONS ===================================================================================================

    get '/sessions' do
      haml :sessions, :layout => true
    end

    get '/sessions/:session_name' do |session_name|
      @session = @project.open_session(session_name)
      haml :session
    end

  end
end