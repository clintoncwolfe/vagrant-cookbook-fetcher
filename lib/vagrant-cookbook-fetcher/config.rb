module VagrantPlugins
  module CookbookFetcher
    class Config < Vagrant.plugin("2", :config)
      attr_accessor :url
      attr_accessor :disable

      def initialize
        super
        @url     = UNSET_VALUE
        @disable = UNSET_VALUE
      end

      def finalize!
        if Vagrant.has_plugin?('vagrant-berkshelf') 
          # TODO: would ideally detect whether berkshelf is actually enabled
          # TODO: this ui call seems to alkways get swallowed
          ui.info('vagrant-berkshelf detected, disabling vagrant-cookbook-fetcher')
          @disable = true
        else 
          @disable = false if @disable == UNSET_VALUE
        end
      end

      def validate(machine)
        errors = []
        if @url == UNSET_VALUE
          # Disable vagrant cookbook fetcher if we don't specify a URL
          @disable = true
        end

        { 'Cookbook Fetcher' => errors }
      end

    end
  end
end
