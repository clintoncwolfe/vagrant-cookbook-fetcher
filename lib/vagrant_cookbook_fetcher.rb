module CookbookFetcher


  class CheckoutCommand < Vagrant::Command::Base
    def execute
      Dir.chdir(@env.root_path) do
        CookbookFetcher.perform_fetch(@env.config.global, @env.ui)
      end
    end
  end
  Vagrant.commands.register(:checkout) { CookbookFetcher::CheckoutCommand }


end
