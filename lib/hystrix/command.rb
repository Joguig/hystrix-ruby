# TODO: implement separate statsd impl
require 'timeout'
require 'drb'

module Hystrix
	class ExecutorPoolFullError < StandardError; end
	class CircuitOpenError < StandardError; end

	class Command
		include Celluloid
		include Logging

		DEFAULT_POOL_SIZE = 10

		attr_accessor :executor_pool, :circuit, :metrics, :events

		class << self
			attr_accessor :config

			def inherited(subclass)
				subclass.instance_eval do
					self.config = {}

					pool_size DEFAULT_POOL_SIZE
				end

				super
			end
		end

		def config
			self.class.config
		end

		def initialize(*args)
			self.executor_pool = CommandExecutorPools.instance.get_pool(executor_pool_name, config[:pool_size])
			self.metrics = Hystrix::CommandMetrics.get(group, config[:metrics] || {})
			self.circuit = Hystrix::Circuit.get(group, config[:circuit] || {})
			self.events = []
		end

		# Run the command synchronously
		def execute
			raise 'No executor pool found! Did you forget to call super in your initialize method?' unless executor_pool

			executor = nil
			start_time = Time.now
			run_duration = 0

			begin
				raise CircuitOpenError unless self.circuit.allow_request?

				executor = executor_pool.take

				# trap exceptions only to capture run_duration
				begin
					result = run_command(executor)
				rescue Exception => e
					raise e
				ensure
					run_duration = Time.now - start_time
				end
				
				handle_success(start_time, run_duration)
			rescue Exception => main_error
				error = (main_error.respond_to?(:cause) and !main_error.cause.nil?) ? main_error.cause : main_error
				handle_error(error, start_time, run_duration)

				begin
					result = fallback(error)
					self.events << :fallback_success
				rescue NotImplementedError
					raise error
				rescue StandardError
					self.events << :fallback_failure
					raise error
				end
			ensure
				Notifications.publish(group, run_duration, self.events)
				executor.unlock if executor
				self.terminate if current_actor.alive?
			end

			return result
		end

		def run_command(executor)
			if config[:timeout_in_milliseconds]
				timeout(config[:timeout_in_milliseconds].to_f / 1000) do
					Timeout::timeout(config[:timeout_in_milliseconds].to_f / 1000) do
						executor.run(self)
					end
				end
			else
				executor.run(self)
			end
		end

		def handle_success(start_time, run_duration)
			self.circuit.async.report_event(:success, start_time, run_duration)
			self.events << :success
		end

		def handle_error(error, start_time, run_duration)
			type = error.class

			metric_type = :failure

			if type == Celluloid::Task::TimeoutError || type == Timeout::Error
				metric_type = :timeout
			elsif type == Hystrix::CircuitOpenError
				metric_type = :short_circuit
			elsif type == Hystrix::ExecutorPoolFullError
				metric_type = :pool_full
			end

			self.events << metric_type
			self.circuit.async.report_event(metric_type, start_time, run_duration)
		end


		# Commands which share the value of executor_pool_name will use the same pool
		def executor_pool_name
			config[:group] || self.class.name
		end
		alias_method :group, :executor_pool_name

		# Run the command asynchronously
		def queue
			future.execute
		end

		def fallback(error)
			raise NotImplementedError
		end

		def self.pool_size(size)
			self.config[:pool_size] = size
		end

		def self.timeout_in_milliseconds(duration)
			self.config[:timeout_in_milliseconds] = duration
		end

		def self.group(group)
			self.config[:group] = group
		end

		def self.circuit_breaker(opts)
			self.config[:circuit] = opts
		end

		def self.metrics(opts)
			self.config[:metrics] = opts
		end
	end
end
