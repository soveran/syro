admin = Syro.new {
  get {
    res.write "GET /admin"
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

  on("users") {
    on(:id) {
      res.write(sprintf("GET /users/%s", inbox[:id]))
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
  }
}

setup do
  Driver.new(app)
end

test "path + verb" do |f|
  f.get("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "GET /foo/bar", f.last_response.body

  f.patch("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "PATCH /foo/bar", f.last_response.body

  f.post("/foo/bar")
  assert_equal 200, f.last_response.status
  assert_equal "POST /foo/bar", f.last_response.body

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

test "root" do |f|
  f.get("/")
  assert_equal "GET /", f.last_response.body
  assert_equal 200, f.last_response.status
end

test "captures" do |f|
  f.get("/users/42")
  assert_equal "GET /users/42", f.last_response.body
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
