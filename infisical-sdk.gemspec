# frozen_string_literal: true

require_relative "lib/infisical/version"

Gem::Specification.new do |spec|
  spec.name = "infisical-sdk"
  spec.version = Infisical::VERSION
  spec.authors = ["Infisical"]
  spec.email = ["support@infisical.com"]

  spec.summary = "Official Infisical SDK for Ruby"
  spec.description = "Native Ruby SDK for fetching and managing secrets with Infisical."
  spec.homepage = "https://github.com/Infisical/ruby-sdk"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/infisical-sdk"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
