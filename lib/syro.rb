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
    LOCATION = "Location".freeze # :nodoc:
    DEFAULT = "text/html".freeze # :nodoc:

    # The status of the response.
    #
    #     res.status = 200
    #     res.status # => 200
    #
    attr_accessor :status

    # Returns the body of the response.
    #
    #     res.body
    #     # => []
    #
    #     res.write("there is")
    #     res.write("no try")
    #
    #     res.body
    #     # => ["there is", "no try"]
    #
    attr :body

    # Returns a hash with the response headers.
    #
    #     res.headers
    #     # => { "Content-Type" => "text/html", "Content-Length" => "42" }
    #
    attr :headers

    def initialize(headers = {})
      @status  = nil
      @headers = headers
      @body    = []
      @length  = 0
    end

    # Returns the response header corresponding to `key`.
    #
    #     res["Content-Type"]   # => "text/html"
    #     res["Content-Length"] # => "42"
    #
    def [](key)
      @headers[key]
    end

    # Sets the given `value` with the header corresponding to `key`.
    #
    #     res["Content-Type"] = "application/json"
    #     res["Content-Type"] # => "application/json"
    #
    def []=(key, value)
      @headers[key] = value
    end

    # Appends `str` to `body` and updates the `Content-Length` header.
    #
    #     res.body # => []
    #
    #     res.write("foo")
    #     res.write("bar")
    #
    #     res.body
    #     # => ["foo", "bar"]
    #
    #     res["Content-Length"]
    #     # => 6
    #
    def write(str)
      s = str.to_s

      @length += s.bytesize
      @headers[Rack::CONTENT_LENGTH] = @length.to_s
      @body << s
    end

    # Sets the `Location` header to `path` and updates the status to
    # `status`. By default, `status` is `302`.
    #
    #     res.redirect("/path")
    #
    #     res["Location"] # => "/path"
    #     res.status      # => 302
    #
    #     res.redirect("http://syro.ru", 303)
    #
    #     res["Location"] # => "http://syro.ru"
    #     res.status      # => 303
    #
    def redirect(path, status = 302)
      @headers[LOCATION] = path
      @status = status
    end

    # Returns an array with three elements: the status, headers and body.
    # If the status is not set, the status is set to 404 if empty body,
    # otherwise the status is set to 200 and updates the `Content-Type`
    # header to `text/html`.
    #
    #     res.status = 200
    #     res.finish
    #     # => [200, {}, []]
    #
    #     res.status = nil
    #     res.finish
    #     # => [404, {}, []]
    #
    #     res.status = nil
    #     res.write("syro")
    #     res.finish
    #     # => [200, { "Content-Type" => "text/html" }, ["syro"]]
    #
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

    # Sets a cookie into the response.
    #
    #     res.set_cookie("foo", "bar")
    #     res["Set-Cookie"] # => "foo=bar"
    #
    #     res.set_cookie("foo2", "bar2")
    #     res["Set-Cookie"] # => "foo=bar\nfoo2=bar2"
    #
    #     res.set_cookie("bar", {
    #       domain: ".example.com",
    #       path: "/",
    #       # max_age: 0,
    #       # expires: Time.now + 10_000,
    #       secure: true,
    #       httponly: true,
    #       value: "bar"
    #     })
    #
    #     res["Set-Cookie"].split("\n").last
    #     # => "bar=bar; domain=.example.com; path=/; secure; HttpOnly
    #
    # **NOTE:** This method doesn't sign and/or encrypt the value of the cookie.
    #
    def set_cookie(key, value)
      Rack::Utils.set_cookie_header!(@headers, key, value)
    end

    # Deletes cookie.
    #
    #     res.set_cookie("foo", "bar")
    #     res["Set-Cookie"]
    #     # => "foo=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 -0000"
    #
    def delete_cookie(key, value = {})
      Rack::Utils.delete_cookie_header!(@headers, key, value)
    end
  end

  class Deck
    module API
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

      def default_headers
        return {}
      end

      def request_class
        Rack::Request
      end

      def response_class
        Syro::Response
      end

      def call(env, inbox)
        @syro_env = env
        @syro_req = request_class.new(env)
        @syro_res = response_class.new(default_headers)
        @syro_path = Seg.new(env.fetch(Rack::PATH_INFO))
        @syro_inbox = inbox

        catch(:halt) do
          instance_eval(&@syro_code)

          @syro_res.finish
        end
      end

      def run(app, inbox = {})
        path, script = env[Rack::PATH_INFO], env[Rack::SCRIPT_NAME]

        env[Rack::PATH_INFO] = @syro_path.curr
        env[Rack::SCRIPT_NAME] = @syro_path.prev
        env[Syro::INBOX] = inbox

        halt(app.call(env))
      ensure
        env[Rack::PATH_INFO], env[Rack::SCRIPT_NAME] = path, script
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
          yield(inbox[arg])

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

    include API
  end

  def initialize(deck = Deck, &code)
    @deck = deck
    @code = code
  end

  def call(env, inbox = env.fetch(Syro::INBOX, {}))
    @deck.new(@code).call(env, inbox)
  end
end
