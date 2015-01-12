vagrant-cookbook-fetcher
========================

A Vagrant plugin to automatically fetch cookbooks, roles, and such whenever you run vagrant provision, up or start.

## Compatibility

For vagrant 1.0.x, use vagrant-cookbook-fetcher 0.0.x .
For vagrant 1.1.x, use vagrant-cookbook-fetcher 0.1.x .  It may or may not work.
For vagrant 1.2.x, use vagrant-cookbook-fetcher 0.1.x .

## Behavior

Once you set a URL in your Vagrantfile that provides a list of checkouts, this plugin will create two directory trees (checkouts and combined):

    my-vagrant-project
     |...Vagrantfile
     |...checkouts
     |   |...checkout-foo
     |   |...checkout-bar
     |...combined
         |...roles
         |...nodes
         |...data_bags
         |...spec_ext

The plugin will loop through the list of checkouts, perform a clone/checkout or pull/update to make sure the checkout exists in the 'checkouts' directory. 

Next, the plugin creates the 'combined' directory.  Each checkout that has a roles directory gets its roles symlinked to; likewise for data bags and nodes.  This feature allows you to have roles defined in multiple checkouts, and used from your local project.  In the event of name collisions, the later checkout wins.  The links are specially constructed to be valid from within the VM, so long as the v-root remains mounted at /vagrant .

Finally, the plugin configures chef-solo, setting the cookbook path (to an ordered array of the checkouts's cookbooks directories), the roles path (to the combined path), and the databags path (to the combined path).  

## Command Integration

The plugin integrates into the existing 'vagrant up', 'vagrant start', and 'vagrant provision' commands.  When running these commands, the cookbooks will be updated before the provision occurs.  Note that if no provision would occur (eg, using 'vagrant up' to resume a suspended VM), then no checkout will occur.

In addition, a new command is added, 'vagrant checkout', which simply runs the checkout and updates the symlinks, without doing a provision.

## Checkout List Format

    git,src@src.omniti.com:~internal/chef/common,omniti-internal-common,multi-repo,chef.key
    git,git@trac-il.omniti.net:myproject/support/chef,myproject-chef,master,AGENT
    git,https://github.com/opscode-cookbooks/php.git,opscode-php/cookbooks/php,master,NONE

The fields are: VCS,repo address, directory name, branch, credentials
 * VCS may be either 'git' or 'svn' (TODO).
 * repo address is the identifier of the repository from which to obtain the checkout.
 * directory name is the path under <vagrant-root>/checkouts to clone/checkout into.  It may contain slashes.
 * branch is the name of the git branch.  Leave blank for svn (use repo address for svn branching)
 * (this feature is TODO) credentials is the method to authenticate to the repo server.  NONE means use no authentication.  AGENT means to rely on a running ssh-agent to provide credentials.  All other values are taken to specify the location of a SSH private key, relative to <vagrant-root>, that should be used with a GIT_SSH wrapper.

## Configuration

### config.cookbook_fetcher.url

Default: none.

URL that replies with a CSV file containing the list of checkouts.

If absent, no fetch occurs.

### config.cookbook_fetcher.disable

Default: false

If true, no checkout will be be run.  This can be useful if you're provisioning frequently and making local changes to your recipes; if you use git rebase, your build will break whenever you have a local change and an incoming change at the same time.

Even if the fetch is disabled, this plugin will still try to tell chef-solo about your cookbook, role, and data_bag paths, unless you override them.

## TODO

 * Add svn support
 * Actually respect the credentials column
 * Make checkout list format less awful, add headers
 * support chef, not just chef-solo
