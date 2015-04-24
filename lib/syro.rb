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

  # Method override parameter
  OVERRIDE = "_method".freeze

  # HTTP environment variables
  PATH_INFO = "PATH_INFO".freeze
  SCRIPT_NAME = "SCRIPT_NAME".freeze
  REQUEST_METHOD = "REQUEST_METHOD".freeze

  # Content-override comparison string, preemptively
  # frozen for performance
  POST = "POST".freeze

  # Response headers
  LOCATION = "Location".freeze
  CONTENT_TYPE = "Content-Type".freeze
  CONTENT_LENGTH = "Content-Length".freeze
  CONTENT_TYPE_DEFAULT = "text/html".freeze

  class Response
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
      @headers[Syro::CONTENT_LENGTH] = @length.to_s
      @body << s
    end

    def redirect(path, status = 302)
      @headers[Syro::LOCATION] = path
      @status  = status
    end

    def finish
      [@status, @headers, @body]
    end

    def set_cookie(key, value)
      Rack::Utils.set_cookie_header!(@headers, key, value)
    end

    def delete_cookie(key, value = {})
      Rack::Utils.delete_cookie_header!(@headers, key, value)
    end
  end

  class Sandbox
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
      @syro_res = Syro::Response.new({})
      @syro_path = Seg.new(env.fetch(Syro::PATH_INFO))
      @syro_inbox = inbox


      if env[Syro::REQUEST_METHOD] == Syro::POST
        value = @syro_req.POST[Syro::OVERRIDE]

        if value != nil
          env[Syro::REQUEST_METHOD] = value.upcase
        end
      end

      result = catch(:halt) do
        instance_eval(&@syro_code)

        @syro_res.status = 404
        @syro_res.finish
      end

      if result[0].nil?
        if result[2].empty?
          result[0] = 404
        else
          result[1][Syro::CONTENT_TYPE] ||=
                    Syro::CONTENT_TYPE_DEFAULT
          result[0] = 200
        end
      end

      result
    end

    def run(app, inbox = {})
      env[Syro::PATH_INFO] = @syro_path.curr
      env[Syro::SCRIPT_NAME] = @syro_path.prev

      halt(app.call(env, inbox))
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

  def initialize(&block)
    @sandbox = Sandbox.new(block)
  end

  def call(env, inbox = {})
    @sandbox.call(env, inbox)
  end
end
