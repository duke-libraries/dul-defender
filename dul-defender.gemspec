# frozen_string_literal: true

require_relative "lib/dul/defender/version"

Gem::Specification.new do |spec|
  spec.name = "dul-defender"
  spec.version = Dul::Defender::VERSION
  spec.authors = ["David Chandek-Stark"]
  spec.email = ["david.chandek.stark@duke.edu"]

  spec.summary = "A Rack::Attack wrapper for Duke University Libraries' Ruby/Rails apps."
  spec.homepage = "https://github.com/duke-libraries/dul-defender.git"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rack-attack"

  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
end
