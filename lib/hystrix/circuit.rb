require 'atomic'
require 'net/http'
require 'json'

# Circuit-breaker to track and disable commands based on previous attempts
module Hystrix
	class Circuit
		include Celluloid
		include Logging

		DEFAULT_SLEEP_WINDOW = 5000
		DEFAULT_ERROR_THRESHOLD = 50
		DEFAULT_MIN_REQUESTS = 20

		attr_reader :sleep_window, :error_threshold, :min_requests, :key, :metrics

		def initialize(key, opts, metrics)
			@key = key
			@metrics = metrics
			@open = false
			@time_opened = Atomic.new(nil)
			@sleep_window = opts[:sleep_window_in_milliseconds] || DEFAULT_SLEEP_WINDOW
			@error_threshold = opts[:error_threshold] || DEFAULT_ERROR_THRESHOLD
			@min_requests = opts[:min_requests] || DEFAULT_MIN_REQUESTS
		end

		@@circuits = {}
		@@lock = Mutex.new
		def self.get(key, properties)
			circuit = @@circuits[key]
			metrics = Hystrix::CommandMetrics.get(key, create: false)

			if !circuit && properties[:create] != false
				@@lock.synchronize do
					if Hystrix.remote and !properties[:force_local]
						@@circuits[key] ||= Hystrix::RemoteCircuit.supervise(key, properties, metrics)
					else
						@@circuits[key] ||= Hystrix::Circuit.supervise(key, properties, metrics)
					end
				end
				circuit = @@circuits[key]
			end

			return nil if circuit.nil?

			circuit.actors.first
		end

		def self.reset!
			@@lock.synchronize do
				@@circuits = {}
			end
		end

		def self.all
			all = {}
			for name, cb in @@circuits
				all[name] = cb.actors.first
			end
			return all
		end

		def metrics
			return @metrics
		end

		def allow_request?
			closed? || allow_single_request?
		end

		def open?
			open! if should_open?
			
			return @open
		end

		def closed?
			!open?
		end

		def mark_success
			if @open
				close!
				@metrics.reset!
			end
		end

		def report_event(type, start_time, run_duration)
			if type == :success
				mark_success
			end

			metrics.counter.increment(type)
			metrics.execute_timing.add(run_duration * 1000)
			metrics.total_timing.add((Time.now - start_time) * 1000)
		end

		private

		def sleep_window_passed?
			Time.now - @time_opened.value > (sleep_window / 1000)
		end

		def allow_single_request?
			time_opened = @time_opened.value
			if sleep_window_passed?
				# TODO: should we allow calls to remote here to grab allowance?
				return @time_opened.compare_and_swap(time_opened, Time.now)
			end

			false
		end

		def open!
			return if @open

			@open = true
			@time_opened.swap(Time.now)
			logger.info("Hystrix::Circuit (#{@key})") { "Circuit open: #{status}" }
		end

		def close!
			@open = false
			@time_opened.swap(nil)
			logger.info("Hystrix::Circuit (#{@key})") { "Circuit closed: #{status}" }
		end

		def should_open?
			snapshot = @metrics.health_snapshot
			snapshot[:total] >= min_requests && snapshot[:error_percentage] >= error_threshold
		end

		def status
			snapshot = @metrics.health_snapshot
			"%d/%d reqs - %.2f/%.2f err%" % [snapshot[:total], min_requests,
				snapshot[:error_percentage], error_threshold]
		end
	end
end
