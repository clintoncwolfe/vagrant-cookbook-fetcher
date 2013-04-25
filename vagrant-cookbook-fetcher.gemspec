# -*-ruby-*-

$:.push File.expand_path(File.join(File.dirname(__FILE__), "lib"))
require "vagrant-cookbook-fetcher"

Gem::Specification.new do |s|
  s.name              = VagrantPlugins::CookbookFetcher::NAME
  s.version           = VagrantPlugins::CookbookFetcher::VERSION
  s.authors           = VagrantPlugins::CookbookFetcher::AUTHOR
  s.email             = VagrantPlugins::CookbookFetcher::AUTHOR_EMAIL
  s.homepage          = VagrantPlugins::CookbookFetcher::URL
  s.rubyforge_project = VagrantPlugins::CookbookFetcher::NAME
  s.summary           = VagrantPlugins::CookbookFetcher::DESCRIPTION
  s.description       = VagrantPlugins::CookbookFetcher::SUMMARY
  s.files = ["README.md"] + Dir["lib/**/*.*"]
end
