module VagrantPlugins
  module CookbookFetcher

    # Utility method - reads the config, fetches the checkout list, 
    # does the checkout, and does the crosslinks.  Expects cwd to be the root_path.
    def perform_fetch (args = {})
      url    = args[:url]
      logger = args[:logger]
      path   = args[:path]

      unless url then
        logger.warn "No cookbook_fetcher URL specified - skipping checkouts"
        return
      end
    
      Dir.chdir(path) do
        checkouts = CookbookFetcher.fetch_checkout_list(url,logger)
        CookbookFetcher.perform_checkouts(checkouts,logger)
        CookbookFetcher.update_links(checkouts,logger)
      end
    end
    module_function :perform_fetch


    private

    # Utility method, fetches checkout list, parses it, 
    # and writes cookbook order to a file in the current working directory.
    def fetch_checkout_list (url, logger)
      require 'open-uri'
    
      checkouts = { :by_dir => {}, :cookbook_list => [] } 
      
      logger.info "Fetching checkout list from #{url}"

      # This is idiotic, but open-uri's open() fails on URLs like 'file:///...'
      # It does fine on absolute paths, though.
      url.gsub!(/^file:\/\//, '')

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

    def safe_run (cmd, logger, ignore_regex = nil)
      if logger.respond_to?(:debug) 
        logger.debug("Running #{cmd}")
      end
      output = `#{cmd} 2>&1`
      unless $?.success? then
        pwd = Dir.pwd
        logger.error("Got exit code #{$?.exitstatus} while running '#{cmd}' in '#{pwd}'")
        logger.error("Output: #{output}")
        exit $?.exitstatus
      end
      if (ignore_regex)
        output.gsub!(ignore_regex, '')
      end
      output.chomp!
      unless output.empty? 
        puts output
      end
    end
    module_function :safe_run

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
                safe_run(cmd, logger)
                cmd = "git fetch origin"
                safe_run(cmd, logger)

                local_branch = `git rev-parse --verify --symbolic-full-name #{info[:branch]} 2> /dev/null`.rstrip
                # no local branch
                if ! $?.success? then
                  cmd = "git rev-parse --verify -q --symbolic-full-name origin/#{info[:branch]}"
                  unless system cmd then raise "Could not find branch or commit #{info[:branch]}" end
                  cmd = "git checkout -b #{info[:branch]} origin/#{info[:branch]}"
                  safe_run(cmd, logger)

                elsif local_branch.empty? then
                  # no branch
                  cmd = "git checkout #{info[:branch]}"
                  safe_run(cmd, logger)
                else
                  # local branch already exists
                  cmd = "git checkout #{info[:branch]}"
                  safe_run(cmd, logger, /Already on '.+'/)
                  cmd = "git merge origin/#{info[:branch]}"
                  safe_run(cmd, logger, /Already up-to-date\./)
                end
              end
            else
              # clone
              # can't use --branch because it won't work with commit ids
              cmd = "git clone --no-checkout #{info[:repo]} #{info[:dir]}"
              safe_run(cmd, logger)
              Dir.chdir(info[:dir]) do
                cmd = "git rev-parse --verify -q origin/#{info[:branch]}"
                # branch
                if system cmd then
                  current_branch=`git symbolic-ref HEAD 2> /dev/null`.rstrip
                  if $?.success? && current_branch == "refs/heads/#{info[:branch]}" then
                    cmd = "git checkout #{info[:branch]}"
                    safe_run(cmd, logger)
                  else
                    cmd = "git checkout -B #{info[:branch]} origin/#{info[:branch]}"
                    safe_run(cmd, logger)
                  end
                  #commit
                else
                  cmd = "git checkout #{info[:branch]}"
                  safe_run(cmd, logger)
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
  end
end
