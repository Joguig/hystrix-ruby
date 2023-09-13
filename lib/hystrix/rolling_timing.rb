module Hystrix
	class RollingTiming
		def initialize(window_secs = 60)
			@window_secs = window_secs
			@buckets = {}
		end

		def self.ordinal(length, percentile)
			if percentile == 0 and length > 0
				return 1
			end

			return (percentile.to_f / 100.0 * length.to_f).ceil
		end

		# duration in milliseconds
		def add(duration)
			current_bucket << duration.to_i

			cleanup
		end

		def mean
			durations = sorted_durations

			sum = durations.inject(:+)
			len = durations.size

			if len == 0
				return 0
			end

			return sum / len
		end

		def percentile(p)
			durations = sorted_durations

			len = durations.size
			if len == 0
				return 0
			end

			return durations[self.class.ordinal(len, p) - 1]
		end

		def timings
			{
				'0' => percentile(0),
				'25' => percentile(25),
				'50' => percentile(50),
				'75' => percentile(75),
				'90' => percentile(90),
				'95' => percentile(95),
				'99' => percentile(99),
				'99.5' => percentile(99.5),
				'100' => percentile(100)
			}
		end

		def current_bucket
			now = Time.now.strftime('%s').to_i
			@buckets[now] ||= []

			return @buckets[now]
		end

		def cleanup
			now = Time.now.strftime('%s').to_i

			for ts, bucket in @buckets
				if ts <= now - @window_secs
					@buckets.delete(ts)
				end
			end
		end

		def sorted_durations
			durations = []
			for ts, bucket in @buckets
				durations += bucket
			end

			return durations.sort!
		end
	end
end