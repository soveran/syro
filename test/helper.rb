require_relative "../lib/syro"
require "rack/test"

class Driver
  include Rack::Test::Methods

  def initialize(app)
    @app = app
  end

  def app
    @app
  end
end

