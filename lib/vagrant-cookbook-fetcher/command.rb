require_relative 'guts'

module VagrantPlugins
  module CookbookFetcher
    class CheckoutCommand < Vagrant.plugin("2", "command")
      def execute

        # Oddly, under vagrant ~ 1.4.1, @argv is ['--'].
        # Disappearred by 1.7.2
        scrubbed_args = @argv.reject {|e| e == '--' }
        with_target_vms(scrubbed_args) do |machine|

          CookbookFetcher.perform_fetch(
                                        :url => machine.config.cookbook_fetcher.url,
                                        :logger => @env.ui,
                                        :path => @env.root_path
                                        )
        end
      end
    end
  end
end
