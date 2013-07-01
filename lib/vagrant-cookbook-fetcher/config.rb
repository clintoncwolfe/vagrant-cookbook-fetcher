module VagrantPlugins
  module CookbookFetcher
    class Config < Vagrant.plugin("2", :config)
      attr_writer :url
      attr_writer :disable

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
        unless @disable then
          if @url == UNSET_VALUE
            errors << "vagrant-cookbook-fetcher plugin requires a config parameter, 'url', which is missing."
          end
        end

        { 'Cookbook Fetcher' => errors }
      end

    end
  end
end
