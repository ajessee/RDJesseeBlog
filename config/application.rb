require_relative "boot"

require "rails/all"
require 'elasticsearch/rails/instrumentation'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RdjesseeBlog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    # No shared cache backend is configured; adopt the format required by Rails 7.2.
    config.active_support.cache_format_version = 7.1
    # Upload Active Storage blobs before the recording conversion callback reads them.
    config.active_record.run_after_transaction_callbacks_in_order_defined = true

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
