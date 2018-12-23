# frozen_string_literal: true

module Orchestration
  module DockerCompose
    class Configuration
      def initialize(env, environment, selected_services)
        @env = env # Global environment
        @environment = environment # Current build environment
        @selected_services = selected_services
      end

      def version
        @env.docker_api_version
      end

      def services
        Hash[services_enabled]
      end

      def volumes
        {
          @env.public_volume => {}
        }.merge(database_volume)
      end

      private

      def services_available
        {
          application: ApplicationService,
          database: DatabaseService,
          mongo: MongoService,
          rabbitmq: RabbitMQService,
          nginx_proxy: NginxProxyService
        }
      end

      def services_enabled
        @selected_services.map do |service, config|
          definition = service_definition(service, config)
          next if definition.nil?

          [service.to_s, definition]
        end.compact
      end

      def database_volume
        return {} unless services.key?('database')

        { @env.database_volume => {} }
      end

      def service_definition(service, config)
        services_available
          .fetch(service)
          .new(config, @environment)
          .definition
      end
    end
  end
end
