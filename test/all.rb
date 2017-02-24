require "json"

class RackApp
  def call(env)
    [200, {"Content-Type" => "text/html"}, ["GET /rack"]]
  end
end

class TextualDeck < Syro::Deck
  def text(str)
    res[Rack::CONTENT_TYPE] = "text/plain"
    res.write(str)
  end
end

class DefaultHeaders < Syro::Deck
  def default_headers
    { Rack::CONTENT_TYPE => "text/html" }
  end
end

class CustomRequestAndResponse < Syro::Deck
  class JSONRequest < Rack::Request
    def params
      JSON.parse(body.read)
    end
  end

  class JSONResponse < Syro::Response
    def write(s)
      super(JSON.generate(s))
    end
  end

  def request_class
    JSONRequest
  end

  def response_class
    JSONResponse
  end
end

textual = Syro.new(TextualDeck) do
  get do
    text("GET /textual")
  end
end

default_headers = Syro.new(DefaultHeaders) do end

json = Syro.new(CustomRequestAndResponse) do
  root do
    params = req.params

    res.write(params)
  end
end

admin = Syro.new do
  get do
    res.write("GET /admin")
  end
end

platforms = Syro.new do
  @id = inbox.fetch(:id)

  get do
    res.write "GET /platforms/#{@id}"
  end
end

comments = Syro.new do
  get do
    res.write sprintf("GET %s/%s/comments",
      inbox[:path],
      inbox[:post_id])
  end
end

app = Syro.new do
  get do
    res.write "GET /"
  end

  post do
    on req.POST["user"] != nil do
      res.write "POST / (user)"
    end

    on true do
      res.write "POST / (none)"
    end
  end

  on "foo" do
    on "bar" do
      on "baz" do
        res.write("error")
      end

      get do
        res.write("GET /foo/bar")
      end

      put do
        res.write("PUT /foo/bar")
      end

      head do
        res.write("HEAD /foo/bar")
      end

      post do
        res.write("POST /foo/bar")
      end

      patch do
        res.write("PATCH /foo/bar")
      end

      delete do
        res.write("DELETE /foo/bar")
      end

      options do
        res.write("OPTIONS /foo/bar")
      end
    end
  end

  on "bar/baz" do
    get do
      res.write("GET /bar/baz")
    end
  end

  on "admin" do
    run(admin)
  end

  on "platforms" do
    run(platforms, id: 42)
  end

  on "rack" do
    run(RackApp.new)
  end

  on "users" do
    on :id do
      res.write(sprintf("GET /users/%s", inbox[:id]))
    end
  end

  on "posts" do
    @path = path.prev

    on :post_id do
      on "comments" do
        run(comments, inbox.merge(path: @path))
      end
    end
  end

  on "one" do
    @one = "1"

    get do
      res.write(@one)
    end
  end

  on "two" do
    get do
      res.write(@one)
    end

    post do
      res.redirect("/one")
    end
  end

  on "textual" do
    run(textual)
  end

  on "headers" do
    run(default_headers)
  end

  on "json" do
    run(json)
  end

  on "private" do
    res.status = 401
    res.write("Unauthorized")
  end
end

setup do
  Driver.new(app)
end

test "path + verb" do |f|
  f.get("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "GET /foo/bar", f.last_response.body

  f.get("/bar/baz")
  assert_equal 404, f.last_response.status
  assert_equal "", f.last_response.body

  f.put("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "PUT /foo/bar", f.last_response.body

  f.head("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "HEAD /foo/bar", f.last_response.body

  f.post("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "POST /foo/bar", f.last_response.body

  f.patch("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "PATCH /foo/bar", f.last_response.body

  f.delete("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "DELETE /foo/bar", f.last_response.body

  f.options("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "OPTIONS /foo/bar", f.last_response.body
end

test "verbs match only on root" do |f|
  f.get("/bar/baz/foo")
  assert_equal "", f.last_response.body
  assert_equal 404, f.last_response.status
end

test "mounted app" do |f|
  f.get("/admin")
  assert_equal "GET /admin", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "mounted app + inbox" do |f|
  f.get("/platforms")
  assert_equal "GET /platforms/42", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "run rack app" do |f|
  f.get("/rack")
  assert_equal "GET /rack", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "root" do |f|
  f.get("/")
  assert_equal "GET /", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "captures" do |f|
  f.get("/users/42")
  assert_equal "GET /users/42", f.last_response.body

  # As the verb was not mached, the status is 404.
  assert_equal 404, f.last_response.status
end

test "post values" do |f|
  f.post("/", "user" => { "username" => "foo" })
  assert_equal "POST / (user)", f.last_response.body
  assert_equal 200, f.last_response.status

  f.post("/")
  assert_equal "POST / (none)", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "inherited inbox" do |f|
  f.get("/posts/42/comments")
  assert_equal "GET /posts/42/comments", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "leaks" do |f|
  f.get("/one")
  assert_equal "1", f.last_response.body
  assert_equal 200, f.last_response.status

  f.get("/two")
  assert_equal "", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "redirect" do |f|
  f.post("/two")
  assert_equal 302, f.last_response.status

  f.follow_redirect!
  assert_equal "1", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "custom deck" do |f|
  f.get("/textual")
  assert_equal "GET /textual", f.last_response.body
  assert_equal "text/plain", f.last_response.headers["Content-Type"]
  assert_equal 200, f.last_response.status
end

test "default headers" do |f|
  f.get("/headers")

  assert_equal "text/html", f.last_response.headers["Content-Type"]
end

test "custom request and response class" do |f|
  params = JSON.generate(foo: "foo")

  f.post("/json", params)

  assert_equal params, f.last_response.body
end

test "set content type if body is set" do |f|
  f.get("/private")

  assert_equal 401, f.last_response.status
  assert_equal "Unauthorized", f.last_response.body
  assert_equal "text/html", f.last_response.headers["Content-Type"]
end
