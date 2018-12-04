require File.expand_path('../boot', __FILE__)

require 'rails/all'

require_relative '../app/middleware/rate_limiter'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AirtaskTest
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    config.middleware.use RateLimiter, {
        cache: Redis.new(url: Rails.application.secrets.redis_url),
        max: 100,
        time_window: 60 * 60,
        prefix: 'rate-limit',
        routes: ['/home/index']
    }
  end
end
