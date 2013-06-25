#require 'pry'
#require 'pry-debugger'

module VagrantPlugins
  module CookbookFetcher
    class MissingConfigParam < Vagrant::Errors::VagrantError
      error_key :missing_config_param
    end

    class Config < Vagrant.plugin("2", :config)
      attr_writer :url
      attr_writer :disable

      def initialize
        super
        @url     = UNSET_VALUE
        @disable = UNSET_VALUE
      end

      def finalize!
        puts "DEBUG- In VCF config.rb finalize"
        @disable = false if @disable == UNSET_VALUE
      end

      def validate(machine)
        puts "DEBUG- In VCF config.rb validate"
        errors = []
        puts "DEBUG- VCF config, disable is #{@disable}"
        unless @disable then
          puts "DEBUG- VCF config, disable is false"
          puts "DEBUG- VCF config, url is #{@url.to_s}"
          # Must have a URL
          errors << "vagrant-cookbook-fetcher plugin requires a config parameter, 'url', which is missing."  if !@url
        end

        { 'Cookbook Fetcher' => errors }
      end

    end
  end
end
