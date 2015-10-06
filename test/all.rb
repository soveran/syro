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

textual = Syro.new(TextualDeck) {
  get {
    text("GET /textual")
  }
}

admin = Syro.new {
  get {
    res.write("GET /admin")
  }
}

platforms = Syro.new {
  @id = inbox.fetch(:id)

  get {
    res.write "GET /platforms/#{@id}"
  }
}

comments = Syro.new {
  get {
    res.write sprintf("GET %s/%s/comments",
      inbox[:path],
      inbox[:post_id])
  }
}

app = Syro.new {
  get {
    res.write "GET /"
  }

  post {
    on(req.POST["user"] != nil) {
      res.write "POST / (user)"
    }

    on(true) {
      res.write "POST / (none)"
    }
  }

  on("foo") {
    on("bar") {
      on("baz") {
        res.write("error")
      }

      get {
        res.write("GET /foo/bar")
      }

      put {
        res.write("PUT /foo/bar")
      }

      post {
        res.write("POST /foo/bar")
      }

      patch {
        res.write("PATCH /foo/bar")
      }

      delete {
        res.write("DELETE /foo/bar")
      }
    }
  }

  on("bar/baz") {
    get {
      res.write("GET /bar/baz")
    }
  }

  on("admin") {
    run(admin)
  }

  on("platforms") {
    run(platforms, id: 42)
  }

  on("rack") {
    run(RackApp.new)
  }

  on("users") {
    on(:id) {
      res.write(sprintf("GET /users/%s", inbox[:id]))
    }
  }

  on("articles") {
    on(:id) { |id|
      res.write(sprintf("GET /articles/%s", id))
    }
  }

  on("posts") {
    @path = path.prev

    on(:post_id) {
      on("comments") {
        run(comments, inbox.merge(path: @path))
      }
    }
  }

  on("one") {
    @one = "1"

    get {
      res.write(@one)
    }
  }

  on("two") {
    get {
      res.write(@one)
    }

    post {
      res.redirect("/one")
    }
  }

  on("textual") {
    run(textual)
  }
}

setup do
  Driver.new(app)
end

test "path + verb" do |f|
  f.get("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "GET /foo/bar", f.last_response.body

  f.put("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "PUT /foo/bar", f.last_response.body

  f.post("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "POST /foo/bar", f.last_response.body

  f.patch("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "PATCH /foo/bar", f.last_response.body

  f.delete("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "DELETE /foo/bar", f.last_response.body
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
  assert_equal 200, f.last_response.status

  f.get("/articles/23")
  assert_equal "GET /articles/23", f.last_response.body
  assert_equal 200, f.last_response.status
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
