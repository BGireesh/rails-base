source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "~> 3.1"

# --- Core ---------------------------------------------------------------
gem "rails", "7.0.4"
gem "pg", "~> 1.4"
gem "puma", "5.6.4"
gem "redis", "~> 4.8"

# --- Assets / front-end -------------------------------------------------
gem "sprockets-rails", "~> 3.4"
gem "jsbundling-rails", "~> 1.0"
gem "cssbundling-rails", "~> 1.1"

# --- Background work ----------------------------------------------------
gem "sidekiq", "~> 6.5"

# --- App-level ----------------------------------------------------------
gem "jbuilder", "~> 2.11"
gem "bootsnap", "~> 1.13", require: false
gem "concurrent-ruby", "1.3.4"
gem "nokogiri", "1.13.8"
gem "rack", "2.2.4"
gem "loofah", "2.19.0"
gem "rails-html-sanitizer", "1.4.3"

group :development, :test do
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.2"
  gem "pry-byebug", "~> 3.10"
  gem "debug", "~> 1.6"
end

group :development do
  gem "web-console", "~> 4.2"
  gem "listen", "~> 3.7"
  gem "spring", "~> 4.1"
  gem "rubocop", "~> 1.39", require: false
end
