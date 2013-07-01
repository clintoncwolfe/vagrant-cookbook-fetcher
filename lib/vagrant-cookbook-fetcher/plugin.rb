module VagrantPlugins
  module CookbookFetcher
    class Plugin < Vagrant.plugin("2")
      name "Cookbook Fetcher"

      config "cookbook_fetcher" do
        require_relative "config"
        Config
      end

      # We want to act on 'up' and 'provision'
      [
       :machine_action_up,
       :machine_action_provision
      ].each do |chain| 

        # This hook performs the actual fetch
        action_hook(:cookbook_fetcher_do_fetch, chain) do |hook|
          require_relative "action_fetch_cookbooks"
          hook.before(Vagrant::Action::Builtin::Provision, VagrantPlugins::CookbookFetcher::FetchCookbooksAction)
        end
        
        # This hook configures chef-solo to use a special set of paths
        action_hook(:cookbook_fetcher_set_chef_paths, chain) do |hook|
          require_relative "action_set_chef_paths"
          hook.before(Vagrant::Action::Builtin::Provision, VagrantPlugins::CookbookFetcher::SetChefPathsAction)
        end
      end

      command "checkout" do
        require_relative "command"
        CheckoutCommand
      end

    end
  end
end
