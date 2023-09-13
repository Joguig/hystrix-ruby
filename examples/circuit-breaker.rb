require_relative '../lib/hystrix.rb'

Hystrix::Logging.initialize_logger(STDOUT, ::Logger::ERROR)

class CircuitBreakerCommand < Hystrix::Command
  group :breaker

  circuit_breaker(
    sleep_window_in_milliseconds: 1000,
    error_threshold: 0.1,
    min_requests: 2
  )

  metrics(
    num_buckets: 10,
    window_len: 3,
    snapshot_interval: 0.5
  )

  def initialize(success)
    @success = success
    super
  end

  def run
    puts "trying..."
    if !@success
      raise "#run failure"
    end

    "success"
  end

  def fallback(error)
    "fallback: #{error}"
  end
end

puts "> Normal operation (success)"
5.times do
  puts CircuitBreakerCommand.new(true).execute
  sleep 0.2
end

puts "> Command starts failing, opening circuit"
4.times do
  puts CircuitBreakerCommand.new(false).execute
  sleep 0.2
end

# Circuit breaker configuration is shared between all instances with the same group
result = Hystrix.inline(:breaker) do
  # Since the circuit is open, we short-circuit directly to fallback
  execute { raise "fail" }
  fallback { |error| "fallback: #{error}" }
end
puts result

puts "> Let the circuit switch to half-open, attempting another request"
sleep 1
puts CircuitBreakerCommand.new(true).execute

puts "> The circuit is now reset to closed"
puts CircuitBreakerCommand.new(true).execute
