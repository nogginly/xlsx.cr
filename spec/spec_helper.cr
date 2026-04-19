require "spectator"

require "../src/xlsx"
require "../src/xlsx/internal/*"

Spectator.configure do |config|
  config.fail_blank # Fail on no tests.
  config.randomize  # Randomize test order.
end
