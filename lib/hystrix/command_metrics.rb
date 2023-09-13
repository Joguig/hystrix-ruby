module Hystrix
	class CommandMetrics
		include Celluloid

		DEFAULT_NUM_BUCKETS = 10
		DEFAULT_WINDOW_LEN = 1
		DEFAULT_SNAPSHOT_INTERVAL = 0.5

		attr_reader :counter, :key, :execute_timing, :total_timing

		def initialize(key, opts={})
			@key = key
			num_buckets = opts[:num_buckets] || DEFAULT_NUM_BUCKETS
			window_len = opts[:window_len] || DEFAULT_WINDOW_LEN
			@counter = Hystrix::RollingNumber.new(num_buckets, window_len)

			@execute_timing = Hystrix::RollingTiming.new
			@total_timing = Hystrix::RollingTiming.new

			@snapshot_interval = opts[:snapshot_interval] || DEFAULT_SNAPSHOT_INTERVAL
			calculate_snapshot
		end

		@@metrics = {}
		@@lock = Mutex.new
		def self.get(key, properties)
			metric = @@metrics[key]

			if !metric && properties[:create] != false
				@@lock.synchronize do
					@@metrics[key] ||= Hystrix::CommandMetrics.new(key, properties)
				end
				metric = @@metrics[key]
			end

			metric
		end

		def self.metric_names
			@@metrics.each_value.map(&:key)
		end

		def reset!
			counter.reset!
			calculate_snapshot
		end

		def health_snapshot
			if stale_snapshot?
				calculate_snapshot
			end

			@snapshot
		end

		private

		def stale_snapshot?
			Time.now - @snapshot[:time] > @snapshot_interval
		end

		def calculate_snapshot
			total = rolling_total_count
			error = rolling_error_count

			if total > 0
				error_percentage = error/total.to_f * 100
			else
				error_percentage = 0
			end

			@snapshot = {
				time: Time.now,
				total: total,
				error: error,
				error_percentage: error_percentage.to_i
			}
		end

		def rolling_total_count
			counts = counter.counts
			counts[:success].to_i + counts[:failure].to_i + counts[:timeout].to_i + counts[:short_circuit].to_i + counts[:pool_full].to_i
		end

		def rolling_error_count
			counts = counter.counts
			counts[:failure].to_i + counts[:timeout].to_i + counts[:short_circuit].to_i + counts[:pool_full].to_i
		end
	end
end
