require 'fileutils'

module VagrantPlugins
  module CookbookFetcher

    # Utility method - reads the config, fetches the checkout list, 
    # does the checkout, and does the copying-in.  Expects cwd to be the root_path.
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
        CookbookFetcher.update_copies(checkouts,logger)
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
    # and copies in the roles, nodes, etc.
    def update_copies (checkouts,logger) 
      things_to_link = [
        "roles",
        "nodes",
        "handlers",
        "data_bags",
      ]
      logger.info "Copying into combined/ #{things_to_link.sort.join(', ')}"

      if Dir.exists?("combined") then FileUtils.rm_rf("combined") end
      Dir.mkdir("combined")
      Dir.chdir("combined") do  
        # Create/clear the subdirs
        things_to_link.each do |thing|
          Dir.mkdir(thing)
        end
      end

      # Being careful to go in cookbook order, copy the files
      checkouts[:cookbook_list].each do |cookbook_dir|
        checkout_dir = (cookbook_dir.split('/'))[1]
        things_to_link.each do |thing|
          checkout_thing_dir = "checkouts/#{checkout_dir}/#{thing}"
          combined_dir = "combined/#{thing}"

          # If this checkout has anything to contribute
          if Dir.exists?(checkout_thing_dir) then
            FileUtils.cp_r("#{checkout_thing_dir}/.", combined_dir)
          end
        end
      end  
    end
    module_function :update_copies
  end
end
