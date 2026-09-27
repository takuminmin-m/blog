ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A scratch copy of the fixture content for tests that change files.
    def with_content_copy
      Dir.mktmpdir do |dir|
        FileUtils.cp_r(Rails.configuration.x.content_root.children, dir)
        yield Pathname(dir)
      end
    end
  end
end
