require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.assets.compile = false

  config.force_ssl = false

  config.log_level = :info
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::Logger.new($stdout)
             .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
             .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  config.active_job.queue_adapter = :sidekiq
  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
end
