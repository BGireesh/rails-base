# Compatibility shim for DEVELOPMENT/TEST only.
#
# Gemfile.lock resolved the `json` gem to 3.0.2 (pulled in by rubocop, a
# dev-only dependency). ActiveSupport 7.0.4 still passes `quirks_mode: true`
# to JSON.generate/JSON.parse - an option the json gem removed in 3.0 - which
# breaks every `render json:`, `to_json`, and signed-cookie read with:
# ArgumentError: unknown keyword: quirks_mode
#
# The production Docker image installs a bundle WITHOUT development/test
# gems, so it uses Ruby 3.1's default json 2.6.x and is unaffected - the
# version guard below makes this file a no-op there.
#
# Remove this file once the Gemfile pins json < 3, or Rails is >= 7.1.
require "json"
require "active_support/json/encoding"

if Gem::Version.new(JSON::VERSION) >= Gem::Version.new("3.0")
  module JsonGem3QuirksModeEncodeCompat
    def stringify(jsonifyed)
      ::JSON.generate(jsonifyed, max_nesting: false)
    end
  end

  ActiveSupport::JSON::Encoding::JSONGemEncoder.prepend(JsonGem3QuirksModeEncodeCompat)

  module JsonGem3QuirksModeDecodeCompat
    def decode(json)
      data = ::JSON.parse(json)
      ActiveSupport.parse_json_times ? convert_dates_from(data) : data
    end
  end

  class << ActiveSupport::JSON
    prepend JsonGem3QuirksModeDecodeCompat
  end
end