module CookbookFetcher

  # http://vagrantup.com/v1/docs/extending/configuration.html
  class Config < Vagrant::Config::Base
    attr_accessor :url
    attr_accessor :disable
  end
  Vagrant.config_keys.register(:cookbook_fetcher) { CookbookFetcher::Config }

  # Utility method - reads the config, fetches the checkout list, 
  # does the checkout, and does the crosslinks.  Expects cwd to be the root_path.
  def perform_fetch (global_config, logger)

    unless global_config.cookbook_fetcher then
      logger.warn "No config.cookbook_fetcher section found in Vagrantfile - skipping checkouts"
      return
    end

    url = global_config.cookbook_fetcher.url
    unless url then
      logger.warn "No config.cookbook_fetcher.url value found in Vagrantfile - skipping checkouts"
      return
    end
    
    checkouts = CookbookFetcher.fetch_checkout_list(url,logger)
    CookbookFetcher.perform_checkouts(checkouts,logger)
    CookbookFetcher.update_links(checkouts,logger)
  end
  module_function :perform_fetch

  # Utility method, fetches checkout list, parses it, 
  # and writes cookbook order to a file in the current working directory.
  def fetch_checkout_list (url, logger)
    require 'open-uri'
    
    checkouts = { :by_dir => {}, :cookbook_list => [] } 

    logger.info "Fetching checkout list from #{url}"
    open(url, {:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE }) do |resp|
      resp.each do |line|
        line.chomp!
        if !line.empty? then
          pieces = line.split(/,/)
          branch = pieces[3]
          dir = pieces[2]

          # Build info hash
          checkouts[:by_dir][dir] = {
            :vcs => pieces[0],
            :repo => pieces[1],
            :dir => dir,
            :branch => pieces[3],
            :creds => pieces[4],          
          }
          
          # Build cookbook list.  Use first part of directory, and append cookbooks
          checkouts[:cookbook_list].push 'checkouts/' + (dir.split('/'))[0] + '/cookbooks'

          # Write cookbook order to a file, in case we are later disabled
          File.open('.cookbook-order', 'w') do |f|
            f.print(checkouts[:cookbook_list].join("\n"))
          end
        end
      end
    end
    return checkouts
  end
  module_function :fetch_checkout_list

  # Utility method.  Based on a parsed checkout list, 
  # performs each of the checkouts, creating the checkouts/ directory in 
  # the current directory.
  def perform_checkouts (checkouts,logger)

    if !Dir.exists?("checkouts") then Dir.mkdir("checkouts") end
    
    Dir.chdir("checkouts") do  
      checkouts[:by_dir].each do |dir, info|
        logger.info "Updating checkout '#{dir}'"
        if info[:vcs] == 'git' then

          if Dir.exists?(info[:dir]) then
            # pull
            Dir.chdir(info[:dir]) do
              # TODO ignores git creds
              cmd = "git remote set-url origin #{info[:repo]}"
              unless system cmd then raise "Could not '#{cmd}'" end
              cmd = "git fetch origin"
              unless system cmd then raise "Could not '#{cmd}'" end
              local_branch = `git rev-parse --verify --symbolic-full-name #{info[:branch]} 2> /dev/null`.rstrip
              # no local branch
              if ! $?.success? then
                cmd = "git rev-parse --verify -q --symbolic-full-name origin/#{info[:branch]}"
                unless system cmd then raise "Could not find branch or commit #{info[:branch]}" end
                cmd = "git checkout -b #{info[:branch]} origin/#{info[:branch]}"
                unless system cmd then raise "Could not '#{cmd}'" end
                # no branch
              elsif local_branch.empty? then
                cmd = "git checkout #{info[:branch]}"
                unless system cmd then raise "Could not '#{cmd}'" end
                # local branch already exists
              else
                cmd = "git checkout #{info[:branch]}"
                unless system cmd then raise "Could not '#{cmd}'" end
                cmd = "git merge origin/#{info[:branch]}"
                unless system cmd then raise "Could not '#{cmd}'" end
              end
            end
          else
            # clone
            # can't use --branch because it won't work with commit ids
            cmd = "git clone --no-checkout #{info[:repo]} #{info[:dir]}"
            unless system cmd then raise "Could not '#{cmd}'" end
            Dir.chdir(info[:dir]) do
              cmd = "git rev-parse --verify -q origin/#{info[:branch]}"
              # branch
              if system cmd then
                current_branch=`git symbolic-ref HEAD 2> /dev/null`.rstrip
                if $?.success? && current_branch == "refs/heads/#{info[:branch]}" then
                  cmd = "git checkout #{info[:branch]}"
                  unless system cmd then raise "Could not '#{cmd}'" end
                else
                  cmd = "git checkout -B #{info[:branch]} origin/#{info[:branch]}"
                  unless system cmd then raise "Could not '#{cmd}'" end
                end
                #commit
              else
                cmd = "git checkout #{info[:branch]}"
                unless system cmd then raise "Could not '#{cmd}'" end
              end
            end
          end
        else
          raise "Unsupported VCS '#{info[:vcs]}' in checkout list for entry '#{dir}'"
        end
      end
    end
  end
  module_function :perform_checkouts

  # Utility method - given a parsed checkout list, and assuming the checkout have
  # already been performed, creates the combined/ directory in the current directory,
  # and symlinks in the roles, nodes, etc.
  def update_links (checkouts,logger) 
    things_to_link = {
      "roles"     => {:vagrant_pov_link => true,  :target_dir => "roles",     :step_in => false },
      "nodes"     => {:vagrant_pov_link => true,  :target_dir => "nodes",     :step_in => false },
      "handlers"  => {:vagrant_pov_link => true,  :target_dir => "handlers",  :step_in => false },
      "data_bags" => {:vagrant_pov_link => true,  :target_dir => "data_bags", :step_in => true  },
      "spec_ext"  => {:vagrant_pov_link => false, :target_dir => "spec",      :step_in => false },
      "spec_int"  => {:vagrant_pov_link => true,  :target_dir => "spec",      :step_in => false },
    }
    logger.info "Updating links to #{things_to_link.keys.sort.join(', ')}"

    if !Dir.exists?("combined") then Dir.mkdir("combined") end
    Dir.chdir("combined") do  

      # Create/clear the subdirs
      things_to_link.keys.each do |thing|
        if !Dir.exists?(thing) then Dir.mkdir(thing) end
        if (things_to_link[thing][:step_in]) then
          Dir.foreach(thing) do |top_dir|
            Dir.foreach(thing + '/' + top_dir) do |file|
              if FileTest.symlink?(file) then File.delete(file) end
            end
          end
        else
          Dir.foreach(thing) do |file|
            if FileTest.symlink?(file) then File.delete(file) end
          end
        end
      end
    end

    # Being careful to go in cookbook order, symlink the files
    checkouts[:cookbook_list].each do |cookbook_dir|
      checkout_dir = (cookbook_dir.split('/'))[1]
      things_to_link.each do |thing, opts|
        checkout_thing_dir = "checkouts/#{checkout_dir}/#{opts[:target_dir]}"
        combined_dir = "combined/#{thing}"
        if Dir.exists?(checkout_thing_dir) then
          if opts[:step_in] then
            Dir.foreach(checkout_thing_dir) do |checkout_top_dir|
              next unless File.directory?(checkout_thing_dir + '/' + checkout_top_dir)
              next if checkout_top_dir.start_with?('.')
              combined_top_dir = combined_dir + '/' + checkout_top_dir
              if !Dir.exists?(combined_top_dir) then Dir.mkdir(combined_top_dir) end
              Dir.entries(checkout_thing_dir + '/' + checkout_top_dir).grep(/\.(rb|json)$/).each do |file|
                if opts[:vagrant_pov_link] then
                  # Under vagrant, we see this directory as /vagrant/checkouts/<checkout>/data_bags/<dbag>/<dbag_entry.json>
                  # Use -f so later checkouts can override earlier ones
                  cmd = "ln -sf /vagrant/#{checkout_thing_dir + '/' + checkout_top_dir}/#{file} combined/#{thing}/#{checkout_top_dir}/#{file}"
                  unless system cmd then raise "Could not '#{cmd}'" end
                else
                  # Link as visible to the host machine
                  # Use -f so later checkouts can override earlier ones
                  cmd = "ln -sf ../../#{checkout_thing_dir + '/' + checkout_top_dir}/#{file} combined/#{thing}/#{checkout_top_dir}/#{file}"
                  unless system cmd then raise "Could not '#{cmd}'" end
                end
              end
            end
          else
            Dir.entries(checkout_thing_dir).grep(/\.(rb|json)$/).each do |file|
              if opts[:vagrant_pov_link] then
                # Under vagrant, we see this directory as /vagrant/checkouts/foo/role/bar.rb
                # Use -f so later checkouts can override earlier ones
                cmd = "ln -sf /vagrant/#{checkout_thing_dir}/#{file} combined/#{thing}/#{file}"
                unless system cmd then raise "Could not '#{cmd}'" end
              else
                # Link as visible to the host machine
                # Use -f so later checkouts can override earlier ones
                cmd = "ln -sf ../../#{checkout_thing_dir}/#{file} combined/#{thing}/#{file}"
                unless system cmd then raise "Could not '#{cmd}'" end
              end                
            end
          end
        end
      end
    end  
  end
  module_function :update_links

  # This is a Vagrant middleware plugin, which implements fetching the cookbooks
  # http://vagrantup.com/v1/docs/extending/middleware.html
  class FetchHook
    def initialize(app, env)
      @app = app
    end

    def call(env)
      if !env[:global_config].cookbook_fetcher.disable then
        Dir.chdir(env[:root_path]) do
          CookbookFetcher.perform_fetch(env[:global_config], env[:ui])
        end
      else
        env[:ui].info "Auto-checkout disabled, skipping"
      end

      # Continue daisy chain
      @app.call(env) 
    end
  end

  # Install fetcher hook
  Vagrant.actions[:provision].insert(Vagrant::Action::General::Validate, CookbookFetcher::FetchHook)
  # Note that :up includes :start ( see https://github.com/mitchellh/vagrant/blob/master/lib/vagrant/action/builtin.rb )
  Vagrant.actions[:start].insert(Vagrant::Action::General::Validate, CookbookFetcher::FetchHook)


  # Middleware to tweak chef config
  # Injects auto-checkout-derived chef-solo config
  class ConfigureChef 
    def initialize(app, env)
      @app = app
    end

    def call(env)
      # Do this even if fetch is disabled

      # there has got to be a better way
      provisioners_list = env[:vm].config.to_hash["keys"][:vm].provisioners 

      chef_solo = provisioners_list.find { |p| p.shortcut === :chef_solo }
      if !chef_solo.nil? then
        solo_cfg = chef_solo.config
      
        # TODO - need cwd block
        Dir.chdir(env[:root_path]) do
          if solo_cfg.roles_path.nil? then
            solo_cfg.roles_path = "combined/roles"
          else
            env[:ui].warn "Auto-checkout is keeping your custom chef-solo role path"
          end

          if solo_cfg.data_bags_path.nil? then
            solo_cfg.data_bags_path = "combined/data_bags"
          else
            env[:ui].warn "Auto-checkout is keeping your custom chef-solo data_bags path"
          end

          # Cookbooks has a default
          if solo_cfg.cookbooks_path === ["cookbooks", [:vm, "cookbooks"]] then
            # Read from filesystem
            if !File.exists?(".cookbook-order") then
              env[:ui].error "Auto-checkout could find not a .cookbook-order file.  You need to run provision with autocheckout enabled at least once (or else specify your own cookbook path)"
            end

            cbs = []
            IO.readlines(".cookbook-order").each { |line| cbs.push line.chomp }
            solo_cfg.cookbooks_path = cbs
          else
            env[:ui].warn "Auto-checkout is keeping your custom chef-solo cookbook path"
          end
        end
      end

      # Continue daisy chain
      @app.call(env) 
    end
  end

  Vagrant.actions[:provision].insert(Vagrant::Action::VM::Provision, CookbookFetcher::ConfigureChef)
  Vagrant.actions[:start].insert(Vagrant::Action::VM::Provision, CookbookFetcher::ConfigureChef)

  class CheckoutCommand < Vagrant::Command::Base
    def execute
      Dir.chdir(@env.root_path) do
        CookbookFetcher.perform_fetch(@env.config.global, @env.ui)
      end
    end
  end
  Vagrant.commands.register(:checkout) { CookbookFetcher::CheckoutCommand }


end
