require "vagrant/action/builder"

module VagrantPlugins
  module CookbookFetcher
    module Action
      include Vagrant::Action::Builtin
      
      autoload :DetectCheckoutDisabled, File.expand_path("../action/detect_checkout_disabled", __FILE__)
      autoload :FetchCookbooks, File.expand_path("../action/fetch_cookbooks", __FILE__)
      autoload :UpdateLinks, File.expand_path("../action/update_links", __FILE__)
      autoload :ConfigureChef, File.expand_path("../action/configure_chef", __FILE__)

      def self.run_checkout
        @run_checkout ||= ::Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, DetectCheckoutDisabled do |env1, b2|
            if env1[:checkout_disabled]
              b2.use FetchCookbooks
              b2.use UpdateLinks
            end
          end
          b.use ConfigureChef
        end
      end

    end
  end
end
