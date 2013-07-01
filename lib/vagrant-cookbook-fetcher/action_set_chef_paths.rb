module VagrantPlugins
  module CookbookFetcher
    class SetChefPathsAction

      def initialize(app, env)
        @app = app
      end
      
      def call(env)
        # there has got to be a better way
        provisioners_list = env[:machine].config.vm.provisioners
        chef_solo = provisioners_list.find { |p| p.name === :chef_solo }

        if chef_solo then
          solo_cfg = chef_solo.config

          Dir.chdir(env[:root_path]) do
            # In Vagrant 1.2.x+, these are all arrays
            solo_cfg.roles_path.push [:host, "combined/roles"]
            solo_cfg.data_bags_path.push [:host, "combined/data_bags"]

            # The first time we fetch cookbooks, we store the cookbook order in a file.
            unless File.exists?(".cookbook-order") then
              env[:ui].error "Cookbook Fetcher checkout could find not a .cookbook-order file.  You need to run provision with checkout enabled at least once (or else disable cookbook fetcher)."
              return
            end

            # For cookbook path, Vagrant defaults to this:
            # [[:host, "cookbooks"], [:vm, "cookbooks"]]
            # But we're overriding that.
            solo_cfg.cookbooks_path = []

            # Read from filesystem
            IO.readlines(".cookbook-order").each do |line| 
              solo_cfg.cookbooks_path.push [ :host, line.chomp ]
            end

          end
        end

        # Continue daisy chain
        @app.call(env) 
      end
    end
  end
end
