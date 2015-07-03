# encoding: UTF-8
#
# Copyright (c) 2015 Michel Martens
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require "rack"
require "seg"

class Syro
  INBOX = "syro.inbox".freeze

  class Response
    LOCATION = "Location".freeze
    DEFAULT = "text/html".freeze

    attr_accessor :status

    attr :body
    attr :headers

    def initialize(headers = {})
      @status  = nil
      @headers = headers
      @body    = []
      @length  = 0
    end

    def [](key)
      @headers[key]
    end

    def []=(key, value)
      @headers[key] = value
    end

    def write(str)
      s = str.to_s

      @length += s.bytesize
      @headers[Rack::CONTENT_LENGTH] = @length.to_s
      @body << s
    end

    def redirect(path, status = 302)
      @headers[LOCATION] = path
      @status = status
    end

    def finish
      if @status.nil?
        if @body.empty?
          @status = 404
        else
          @headers[Rack::CONTENT_TYPE] ||= DEFAULT
          @status = 200
        end
      end

      [@status, @headers, @body]
    end

    def set_cookie(key, value)
      Rack::Utils.set_cookie_header!(@headers, key, value)
    end

    def delete_cookie(key, value = {})
      Rack::Utils.delete_cookie_header!(@headers, key, value)
    end
  end

  class Deck
    def initialize(code)
      @syro_code = code
    end

    def env
      @syro_env
    end

    def req
      @syro_req
    end

    def res
      @syro_res
    end

    def path
      @syro_path
    end

    def inbox
      @syro_inbox
    end

    def call(env, inbox)
      @syro_env = env
      @syro_req = Rack::Request.new(env)
      @syro_res = Syro::Response.new
      @syro_path = Seg.new(env.fetch(Rack::PATH_INFO))
      @syro_inbox = inbox

      catch(:halt) do
        instance_eval(&@syro_code)

        @syro_res.finish
      end
    end

    def run(app, inbox = {})
      env[Rack::PATH_INFO] = @syro_path.curr
      env[Rack::SCRIPT_NAME] = @syro_path.prev
      env[Syro::INBOX] = inbox

      halt(app.call(env))
    end

    def halt(response)
      throw(:halt, response)
    end

    def match(arg)
      case arg
      when String then @syro_path.consume(arg)
      when Symbol then @syro_path.capture(arg, inbox)
      when true   then true
      else false
      end
    end

    def on(arg)
      if match(arg)
        yield

        halt(res.finish)
      end
    end

    def root?
      @syro_path.root?
    end

    def root
      if root?
        yield

        halt(res.finish)
      end
    end

    def get
      if root? && req.get?
        yield

        halt(res.finish)
      end
    end

    def put
      if root? && req.put?
        yield

        halt(res.finish)
      end
    end

    def post
      if root? && req.post?
        yield

        halt(res.finish)
      end
    end

    def patch
      if root? && req.patch?
        yield

        halt(res.finish)
      end
    end

    def delete
      if root? && req.delete?
        yield

        halt(res.finish)
      end
    end
  end

  def initialize(deck = Deck, &code)
    @deck = deck
    @code = code
  end

  def call(env, inbox = env.fetch(Syro::INBOX, {}))
    @deck.new(@code).call(env, inbox)
  end
end
