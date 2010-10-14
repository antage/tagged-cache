Gem::Specification.new do |s|
  s.name = "tagged-cache"
  s.version = "1.0.4"
  s.platform = Gem::Platform::RUBY
  s.summary = "ActiveSupport cache adapter with tagged dependencies"
  s.authors = ["Anton Ageev"]
  s.email = "antage@gmail.com"
  s.homepage = "http://github.com/antage/tagged-cache"

  s.required_rubygems_version = ">= 1.3.6"

  s.files = Dir["README.rdoc", "History.txt", "Rakefile", "lib/**/*.rb"]
  s.test_files = Dir["spec/**/*.rb"]

  s.add_dependency "activesupport", ">= 3.0.0"
end
