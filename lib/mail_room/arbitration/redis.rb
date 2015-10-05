require "redis"

module MailRoom
  module Arbitration
    class Redis
      Options = Struct.new(:redis_url, :namespace) do
        def initialize(mailbox)
          redis_url = mailbox.arbitration_options[:redis_url] || "redis://localhost:6379"
          namespace = mailbox.arbitration_options[:namespace]

          super(redis_url, namespace)
        end
      end

      attr_accessor :options

      # Build a new delivery, hold the mailbox configuration
      # @param [MailRoom::Delivery::Sidekiq::Options]
      def initialize(options)
        @options = options
      end

      def deliver?(message)
        uid = message.attr["UID"]
        key = "delivered:#{uid}"

        incr = nil
        redis.multi do |client|
          # At this point, `incr` is a future, which will get its value after 
          # the MULTI command returns.
          incr = client.incr(key)

          # Expire after 1 minute so Redis doesn't get filled up with outdated data.
          client.expire(key, 60)
        end

        incr.value == 1
      end

      private

      def redis
        @redis ||= begin
          redis = ::Redis.new(url: options.redis_url)

          namespace = options.namespace
          if namespace
            require 'redis/namespace'
            ::Redis::Namespace.new(namespace, redis: redis)
          else
            redis
          end
        end
      end
    end
  end
end
