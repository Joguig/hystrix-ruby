module Hystrix
	class RollingNumber
		attr_reader :num_buckets, :window_len

		def initialize(num_buckets, window_len)
			@num_buckets = num_buckets
			@window_len = window_len

			reset!
		end

		def buckets
			catchup_buckets
			@buckets
		end

		def increment(type)
			current_bucket.increment(type)
		end

		def count(type)
			counts[type] || 0
		end

		def counts
			values = buckets.map(&:values)
			values.inject do |hash1, hash2|
				hash1.merge(hash2) do |_, val1, val2|
					 val1 + val2
				end
			end
		end

		def current_bucket
			buckets.last
		end

		def reset!
			@buckets = [Bucket.new(window_len)]
		end

		private

		def catchup_buckets
			bucket = @buckets.last
			while !bucket.in_window?
				window_start = bucket.window_start + window_len
				bucket = Bucket.new(window_len, window_start)
				@buckets << bucket
			end

			if @buckets.length >= num_buckets
				@buckets.shift(@buckets.length - num_buckets)
			end
		end

		class Bucket
			attr_reader :values, :window_start, :window_len

			def initialize(window_len, window_start=Time.now)
				@window_len = window_len
				@window_start = window_start
				@values = {}
			end

			def value(type)
				values[type] || 0
			end

			def increment(type)
				if !values.key?(type)
					@values[type] = 1
				else
					@values[type] += 1
				end
			end

			def in_window?
				Time.now - window_start < window_len
			end
		end
	end
end
