hystrix-ruby
============

Hystrix for Ruby. Currently offers only basic sync/async command execution and fallbacks

Basic Usage
------------

Running a Hystrix command consists of instantiating a Hystrix::Command subclass and calling execute on the object. Hystrix calls the run method if the circuit is open. If the circuit is closed or if the run method raises an exception, Hystrix calls the fallback method.

```
  class MyCommand < Hystrix::Command
    timeout_in_milliseconds 2000

    circuit_breaker(
      sleep_window_in_milliseconds: 5000
      error_threshold: 0.5
      min_requests: 10
    )

    def run
      Net::HTTP.get_response("http://example.com")
    end

    def fallback
      "Could not fetch results"
    end
  end

  result = MyCommand.new.execute
```

Circuits
--------

Hystrix's built-in circuits keep track of how often commands fail and temporarily prevents the command from running if it has failed too frequently recently. Hystrix keeps track of a sliding window of request successes/failures for each command (or command group). If we had more than the minimum requests in the sliding window and enough of them failed (timed out or raised errors), the circuit is opened.

Command options
---------------

timeout: float (seconds). Amount of time to let a command run before aborting the request and calling the fallback.

group: string. Commands with the same group will share a circuit.

circuit_breaker
  sleep_window: int (seconds). After a circuit is open, number of seconds to wait until trying another request.
  error_threshold: float (0-1). Circuits are opened after this portion of requests fail (if min_requests is also met)
  min_requests: int. Circuits are opened only if the number of requests in our sliding window is at least this much.

metrics
  num_buckets: int. Number of buckets. num_buckets * window_len = sliding window size.
  window_len: float (seconds). Length of each bucket in seconds
  snapshot_interval: float (seconds). How often to recalcuate rolling window statistics

Choosing reasonable circuit values
----------------------------------

Circuits should be configured so that an unresponsive external service does not bring down the application. Factors that go into this include:
  How often does this command get run?
  How many threads is your application running on?
  What's the timeout for the command?

Your circuit configuration should ensure that even if every call of a command times out, we open the circuit in a reasonable amount of time and that min_requests can still be met.

## Configuration

Set log level

    Hystrix::Logging.initialize_logger(STDOUT, ::Logger::WARN)
