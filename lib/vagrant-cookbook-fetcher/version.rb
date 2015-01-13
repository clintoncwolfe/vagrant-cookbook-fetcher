module VagrantPlugins
  module CookbookFetcher
    NAME            = "vagrant-cookbook-fetcher"
    VERSION         = "0.2.1"
    AUTHOR          = "Clinton Wolfe"
    AUTHOR_EMAIL    = "clintoncwolfe [at] gmail [dot] com"
    SUMMARY         = "Fetch your Chef cookbooks whenever you provision"
    DESCRIPTION     = "Whenever you run start, up, or provision, this plugin will dynamically fetch a list of checkouts from a URL; checkout each one; then create a combined roles directory, with symlinks."
    URL             = "http://github.com/clintoncwolfe/vagrant-cookbook-fetcher"    
  end
end

# Some older Vagrantfiles looked for this symbol to detect VCF.
module CookbookFetcher 
end
