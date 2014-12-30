require 'bundler/setup'
Bundler.setup

require 'apothecary' # and any other gems you need
require 'fileutils'
require 'webmock/rspec'
WebMock.disable_net_connect!

RSpec.configure do |config|
  # some (optional) config here
end