require 'sinatra/base'
require 'liquid'

module Apothecary
  class WebApp < Sinatra::Base

    set :app_file, __FILE__
    set :root, File.expand_path('../web', __FILE__)

    get '/' do
      liquid :index
    end

  end
end