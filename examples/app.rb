require 'sinatra/base'
require_relative '../lib/hystrix.rb'

TIMEOUT = 2
class DoWorkCommand < ::Hystrix::Command
  timeout TIMEOUT

  circuit_breaker(
    sleep_window_in_milliseconds: 5000,
    error_threshold: 0.2,
    min_requests: 5
  )

  metrics(
    num_buckets: 15,
    window_len: 5,
    snapshot_interval: 0.1
  )

  def run
    Kernel.sleep TIMEOUT + 2
    return 'success'
  end

  def fallback(error)
    puts 'got to fb'
    return 'fallback'
  end
end


class MyApp < Sinatra::Base
  get '/circuit' do
    DoWorkCommand.new.execute
  end
end

Thread.new do
  MyApp.run!
end

# Wait for server
while true do
  sleep 1
  break if MyApp.running?
end


puts "Making 10 requests..."
10.times do
  start = Time.now
  res = `curl -s -m 5 'localhost:4567/circuit'`

  duration = Time.now - start
  if res == 'success'
    puts "Suceeded in #{duration}"
  elsif res == 'fallback'
    msg = "Fallback in #{duration}"
    msg += " (short-circuit)" if duration < TIMEOUT
    puts msg
  else
    puts "Unexpected response (curl likely timed out)"
  end

  sleep 1
end
