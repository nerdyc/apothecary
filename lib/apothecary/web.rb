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
        @session ||= project.open_session(params[:session_name])
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

    get '/sessions/:session_name' do
      haml :session
    end

    post '/sessions/:session_name/requests' do
      request = session.perform_request!(params[:request_name])
      redirect to("/sessions/#{session.name}")
    end

    get '/sessions/:session_name/requests/:request_identifier' do |session_name, request_identifier|
      @session_request = session.request_with_identifier(request_identifier)
      haml :session_request
    end

  end
end