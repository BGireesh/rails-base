require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module FleetBilling
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = false
    config.active_job.queue_adapter = :sidekiq
    config.time_zone = "UTC"

    config.autoload_paths << Rails.root.join("lib")
  end
end
