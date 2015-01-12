require_relative 'guts'
module VagrantPlugins
  module CookbookFetcher
    class CheckoutCommand < Vagrant.plugin("2", "command")
      def execute
        CookbookFetcher.perform_fetch(
                                      :url => @env.config_global.cookbook_fetcher.url,
                                      :logger => @env.ui,
                                      :path => @env.root_path
                                      )
      end
    end
  end
end
