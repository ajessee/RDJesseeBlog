require_relative "boot"

require "rails/all"
require 'elasticsearch/rails/instrumentation'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RdjesseeBlog
  class Application < Rails::Application
    config.load_defaults 8.1
    # Existing permanent remember-me and session cookies derive their keys with SHA-1.
    # Retain that derivation until production cookies can be migrated with rotations.
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1
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
