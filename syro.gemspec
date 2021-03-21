Gem::Specification.new do |s|
  s.name              = "syro"
  s.version           = "3.2.1"
  s.summary           = "Simple router"
  s.description       = "Simple router for web applications"
  s.authors           = ["Michel Martens"]
  s.email             = ["michel@soveran.com"]
  s.homepage          = "https://github.com/soveran/syro"
  s.license           = "MIT"

  s.files = `git ls-files`.split("\n")

  s.add_dependency "seg"
  s.add_dependency "rack", ">= 1.6.0"
  s.add_development_dependency "cutest"
  s.add_development_dependency "rack-test"
end
