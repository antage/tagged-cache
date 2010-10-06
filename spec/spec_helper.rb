require 'rspec'

Rspec.configure do |c|
  c.mock_with :rspec
end

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
