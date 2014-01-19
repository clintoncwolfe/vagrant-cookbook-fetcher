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
        @disable = false if @disable == UNSET_VALUE
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
