
module VagrantPlugins
  module CookbookFetcher
    class Config < Vagrant.plugin("2", :config)
      attr_writer :url
      attr_writer :disable

      def initialize
        @url     = UNSET_VALUE
        @disable = UNSET_VALUE
      end

      def finalize!
        @disable = false if @disable == UNSET_VALUE
        unless @disable then
          # Must have a URL
          unless @url then
            # TODO raise error?
          end
        end
      end

    end
  end
end
