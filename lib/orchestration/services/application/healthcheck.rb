# frozen_string_literal: true

module Orchestration
  module Services
    module Application
      class Healthcheck
        include HealthcheckBase

        def initialize(env)
          @configuration = Configuration.new(env)
        end

        def connect
          response = Net::HTTP.get_response(
            URI("http://localhost:#{@configuration.local_port}")
          )
          connection_error(response.code) if connection_error?(response.code)
        end

        def connection_errors
          [Errno::ECONNREFUSED, ApplicationConnectionError]
        end

        private

        def connection_error(code)
          raise ApplicationConnectionError,
                I18n.t('orchestration.application.connection_error', code: code)
        end

        def connection_error?(code)
          %w[502 503 500].include?(code)
        end
      end
    end
  end
end
