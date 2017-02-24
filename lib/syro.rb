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
  INBOX = "syro.inbox".freeze # :nodoc:

  class Response
    LOCATION = "Location".freeze # :nodoc:

    module ContentType
      HTML = "text/html".freeze        # :nodoc:
      TEXT = "text/plain".freeze       # :nodoc:
      JSON = "application/json".freeze # :nodoc:
    end

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
    attr_reader :body

    # Returns a hash with the response headers.
    #
    #     res.headers
    #     # => { "Content-Type" => "text/html", "Content-Length" => "42" }
    #
    attr_reader :headers

    def initialize(headers = {})
      @status  = 404
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

    # Write response body as text/plain
    def text(str)
      @headers[Rack::CONTENT_TYPE] = ContentType::TEXT
      write(str)
    end

    # Write response body as text/html
    def html(str)
      @headers[Rack::CONTENT_TYPE] = ContentType::HTML
      write(str)
    end

    # Write response body as application/json
    def json(str)
      @headers[Rack::CONTENT_TYPE] = ContentType::JSON
      write(str)
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

    # Returns an array with three elements: the status, headers and
    # body. If the status is not set, the status is set to 404. If
    # a match is found for both path and request method, the status
    # is changed to 200.
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

    # Deletes given cookie.
    #
    #     res.set_cookie("foo", "bar")
    #     res["Set-Cookie"]
    #     # => "foo=bar"
    #
    #     res.delete_cookie("foo")
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

      # Returns the incoming request object. This object is an
      # instance of Rack::Request.
      #
      #     req.post?      # => true
      #     req.params     # => { "username" => "bob", "password" => "secret" }
      #     req[:username] # => "bob"
      #
      def req
        @syro_req
      end

      # Returns the current response object. This object is an
      # instance of Syro::Response.
      #
      #     res.status = 200
      #     res["Content-Type"] = "text/html"
      #     res.write("<h1>Welcome back!</h1>")
      #
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
        {}
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

      # Immediately stops the request and returns `response`
      # as per Rack's specification.
      #
      #     halt([200, { "Content-Type" => "text/html" }, ["hello"]])
      #     halt([res.status, res.headers, res.body])
      #     halt(res.finish)
      #
      def halt(response)
        throw(:halt, response)
      end

      def consume(arg)
        @syro_path.consume(arg)
      end

      def capture(arg)
        @syro_path.capture(arg, inbox)
      end

      def root?
        @syro_path.root?
      end

      def match(arg)
        case arg
        when String then consume(arg)
        when Symbol then capture(arg)
        when true   then true
        else false
        end
      end

      def default
        yield; halt(res.finish)
      end

      def on(arg)
        default { yield } if match(arg)
      end

      def root
        default { yield } if root?
      end

      def get
        root { res.status = 200; yield } if req.get?
      end

      def put
        root { res.status = 200; yield } if req.put?
      end

      def head
        root { res.status = 200; yield } if req.head?
      end

      def post
        root { res.status = 200; yield } if req.post?
      end

      def patch
        root { res.status = 200; yield } if req.patch?
      end

      def delete
        root { res.status = 200; yield } if req.delete?
      end

      def options
        root { res.status = 200; yield } if req.options?
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
