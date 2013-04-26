
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


      #action "wat" do
      # # TODO
      #end

    end
  end
end
