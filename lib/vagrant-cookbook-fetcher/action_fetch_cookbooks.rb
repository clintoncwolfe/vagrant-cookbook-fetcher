require_relative "guts"

module VagrantPlugins
  module CookbookFetcher
    class FetchCookbooksAction

      def initialize(app, env)
        @app = app
      end

      def call(env)

        vcf_config = env[:machine].config.cookbook_fetcher
        if vcf_config.url then
          CookbookFetcher.perform_fetch(\
                                        :url => vcf_config.url,
                                        :logger => env[:ui],
                                        :path => env[:root_path]
                                        )
        else
          env[:ui].info "Cookbook fetching disabled, skipping"
        end

        # Continue daisy chain
        @app.call(env)
      end
    end
  end
end
