
module VagrantPlugins
  module CookbookFetcher
    class Plugin < Vagrant.plugin("2")
      name "Fetch cookbooks, roles, etc prior to provisioning"

      config "cookbook_fetcher" do
        require_relative "config"
        Config
      end


      #command "checkout" do
      #  require_relative "command"
      #  next VagrantRspecCI::Command
      #end

      autoload :Action, 'vagrant-cookbook-fetcher/action'

      def self.provision(hook)
        hook.before(Vagrant::Action::Builtin::Provision, Action.run_checkout)

        # TODO cargo-culted from vagrant-omnibus

        # BEGIN workaround
        #
        # Currently hooks attached to {Vagrant::Action::Builtin::Provision} are
        # not wired into the middleware return path. My current workaround is to
        # fire after anything boot related which wedges in right before the
        # actual real run of the provisioner.

        hook.after(VagrantPlugins::ProviderVirtualBox::Action::Boot, Action.run_checkout)

        # END workaround

      end

      action_hook(:setup_proxying, :machine_action_up, &method(:provision))
      action_hook(:setup_proxying, :machine_action_provision, &method(:provision))

      # TODO - do we need to register anything for the checkout command?

    end
  end
end
