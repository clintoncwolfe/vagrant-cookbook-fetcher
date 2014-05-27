module VagrantPlugins
  module CookbookFetcher
    class Config < Vagrant.plugin("2", :config)
      attr_accessor :url
    end
  end
end
