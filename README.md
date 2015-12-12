Syro
====

Simple router for web applications.

Community
---------

Meet us on IRC: [#syro](irc://chat.freenode.net/#syro) on
[freenode.net](http://freenode.net/).

Description
-----------

Syro is a very simple router for web applications. It was created
in the tradition of libraries like [Rum][rum] and [Cuba][cuba], but
it promotes a less flexible usage pattern. The design is inspired
by the way some Cuba applications are architected: modularity is
encouraged and sub-applications can be dispatched without any
significant performance overhead.

Check the [website][syro] for more information, and follow the
[tutorial][tutorial] for a step by step introduction.

[rum]: http://github.com/chneukirchen/rum
[cuba]: http://cuba.is
[syro]: http://soveran.github.io/syro/
[tutorial]: http://files.soveran.com/syro/

Usage
-----

An example of a modular application would look like this:

```ruby
admin = Syro.new {
  get {
    res.write "Hello from admin!"
  }
}

app = Syro.new {
  on("admin") {
    run(admin)
  }
}
```

The block is evaluated in a sandbox where the following methods are
available: `env`, `req`, `res`, `path`, `inbox`, `call`, `run`,
`halt`, `consume`, `capture`, `root?` `match`, `default`, `on`,
`root`,`get`, `put`, `head`, `post`, `patch`, `delete` and `options`.
Three other methods are available for customizations: `default_headers`,
`request_class` and `response_class`.

As a recommendation, user created variables should be instance
variables. That way they won't mix with the API methods defined in
the sandbox. All the internal instance variables defined by Syro
are prefixed by `syro_`, like in `@syro_inbox`.

API
---

`env`: Environment variables for the request.

`req`: Helper object for accessing the request variables. It's an
instance of `Rack::Request`.

`res`: Helper object for creating the response. It's an instance
of `Syro::Response`.

`path`: Helper object that tracks the previous and current path.

`inbox`: Hash with captures and potentially other variables local
to the request.

`call`: Entry point for the application. It receives the environment
and optionally an inbox.

`run`: Runs a sub app, and accepts an inbox as an optional second
argument.

`halt`: Terminates the request. It receives an array with the
response as per Rack's specification.

`consume`: Match and consume a path segment.

`capture`: Match and capture a path segment. The value is stored in
the inbox.

`root?`: Returns true if the path yet to be consumed is empty.

`match`: Receives a String, a Symbol or a boolean, and returns true
if it matches the request.

`default`: Receives a block that will be executed inconditionally.

`on`: Receives a value to be matched, and a block that will be
executed only if the request is matched.

`root`: Receives a block and calls it only if `root?` is true.

`get`: Receives a block and calls it only if `root?` and `req.get?` are
true.

`put`: Receives a block and calls it only if `root?` and `req.put?` are
true.

`head`: Receives a block and calls it only if `root?` and `req.head?`
are true.

`post`: Receives a block and calls it only if `root?` and `req.post?`
are true.

`patch`: Receives a block and calls it only if `root?` and `req.patch?`
are true.

`delete`: Receives a block and calls it only if `root?` and `req.delete?`
are true.

`options`: Receives a block and calls it only if `root?` and
`req.options?` are true.

Decks
-----

The sandbox where the application is evaluated is an instance of
`Syro::Deck`, and it provides the API described earlier. You can
define your own `Deck` and pass it to the `Syro` constructor. All
the methods defined in there will be accessible from your routes.
Here's an example:

```ruby
class TextualDeck < Syro::Deck
  def text(str)
    res[Rack::CONTENT_TYPE] = "text/plain"
    res.write(str)
  end
end

App = Syro.new(TextualDeck) {
  get {
    text("hello world")
  }
}
```

The example is simple enough to showcase the concept, but maybe too
simple to be meaningful. The idea is that you can create your own
specialized decks and reuse them in different applications. You can
also define modules and later include them in your decks: for
example, you can write modules for rendering or serializing data,
and then you can combine those modules in your custom decks.

Examples
--------

In the following examples, the response string represents
the request path that was sent.

```ruby
app = Syro.new {
  get {
    res.write "GET /"
  }

  post {
    res.write "POST /"
  }

  on("users") {
    on(:id) {

      # Captured values go to the inbox
      @user = User[inbox[:id]]

      get {
        res.write "GET /users/42"
      }

      put {
        res.write "PUT /users/42"
      }

      patch {
        res.write "PATCH /users/42"
      }

      delete {
        res.write "DELETE /users/42"
      }
    }

    get {
      res.write "GET /users"
    }

    post {
      res.write "POST /users"
    }
  }
}
```

Matches
-------

The `on` method can receive a `String` to perform path matches; a
`Symbol` to perform path captures; and a boolean to match any true
values.

Each time `on` matches or captures a segment of the PATH, that part
of the path is consumed. The current and previous paths can be
queried by calling `prev` and `curr` on the `path` object: `path.prev`
returns the part of the path already consumed, and `path.curr`
provides the current version of the path.

Any expression that evaluates to a boolean can also be used as a
matcher.  For example, a common pattern is to follow some route
only if a user is authenticated. That can be accomplished with
`on(authenticated(User))`. That example assumes there's a method
called `authenticated` that returns true or false depending on
whether or not an instance of `User` is authenticated. As a side
note, [Shield][shield] is a library that provides just that.

[shield]: https://github.com/cyx/shield

Captures
--------

When a symbol is provided, `on` will try to consume a segment of
the path. A segment is defined as any sequence of characters after
a slash and until either another slash or the end of the string.
The captured value is stored in the `inbox` hash under the key that
was provided as the argument to `on`. For example, after a call to
`on(:user_id)`, the value for the segment will be stored at
`inbox[:user_id]`. When mounting an application called `users` with
the command `run(users)`, an inbox can be provided as the second
argument: `run(users, inbox)`. That allows apps to share previous
captures.

Security
--------

There are no security features built into this routing library. A
framework using this library should implement the security layer.

Rendering
---------

There are no rendering features built into this routing library. A
framework that uses this routing library can easily implement helpers
for rendering.

Middleware
----------

Syro doesn't support Rack middleware out of the box. If you need them,
just use `Rack::Builder`:

```ruby
app = Rack::Builder.new do

  use Rack::Session::Cookie, secret: "..."

  run Syro.new {
    get {
      res.write("Hello, world")
    }
  }

end
```

Trivia
------

An initial idea was to release a new version of [Cuba](http://cuba.is)
that broke backward compatibility, but in the end my friends suggested
to release this as a separate library. In the future, some ideas
of this library could be included in Cuba as well.

Installation
------------

```
$ gem install syro
```
