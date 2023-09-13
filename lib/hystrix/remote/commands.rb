module Hystrix
	# RegisterRemoteCircuit return true or false based on if we can configure the remote circuit
	class RegisterRemoteCircuit < Command
		timeout_in_milliseconds 200

		circuit_breaker(
			force_local: true
		)

		def initialize(key, sleep_window, error_threshold, min_requests)
			super

			@key = key
			@sleep_window = sleep_window
			@error_threshold = error_threshold
			@min_requests = min_requests
		end

		def run
			http = Net::HTTP.start(Hystrix.host, Hystrix.port)
			response = http.post '/register', {
				name: @key,
				sleep_window: @sleep_window,
				error_threshold: @error_threshold,
				min_requests: @min_requests,
			}.to_json

			if !response.is_a?(Net::HTTPSuccess)
				raise 'bad response from /register ' + response
			end

			return true
		end

		def fallback(e)
			logger.error("hystrix-ruby: failed to connect to remote for /register: " + e.message)
			return false
		end
	end

	# CheckRemoteConnection returns true or false based on if we can communicate with the remote circuit
	class CheckRemoteConnection < Command
		timeout_in_milliseconds 500

		circuit_breaker(
			force_local: true
		)

		def run
			u = URI("http://#{Hystrix.host}:#{Hystrix.port}/")
			if Net::HTTP.get_response(u).is_a?(Net::HTTPSuccess)
				return true
			else
				return false
			end
		end

		def fallback(e)
			logger.info("hystrix-ruby: attempt to reconnect to remote failed: " + e.message)
			return false
		end
	end

	# ReportRemoteEvent return true or false based on if the command execution metrics were sent to the remote circuit
	class ReportRemoteEvent < Command
		timeout_in_milliseconds 500

		circuit_breaker(
			force_local: true
		)

		def initialize(key, type, start_time, run_duration)
			super

			@key = key
			@type = type
			@start_time = start_time
			@run_duration = run_duration
		end

		def run
			http = Net::HTTP.start(Hystrix.host, Hystrix.port)
			response = http.post '/event', {
				name: @key,
				type: @type,
				start_time: (@start_time.to_f * 1_000_000_000).to_i, # nanoseconds
				run_duration: (@run_duration * 1_000_000_000).to_i # nanoseconds
			}.to_json

			if !response.is_a?(Net::HTTPSuccess)
				raise 'bad response from /event ' + response
			end

			return true
		end

		def fallback(e)
			logger.error("hystrix-ruby: failed to connect to remote for /event: " + e.message)
			return false
		end
	end

	# AllowRemoteRequest returns true or false based on if the remote circuit is allowing requests
	# It will throw an exception if communication with the remote circuit fails
	class AllowRemoteRequest < Command
		timeout_in_milliseconds 200

		circuit_breaker(
			force_local: true
		)

		def initialize(key)
			super
			
			@key = key
		end

		def run
			u = URI("http://#{Hystrix.host}:#{Hystrix.port}/allow")
			u.query = URI.encode_www_form(name: @key)
			response = Net::HTTP.get_response(u)
			if response.is_a?(Net::HTTPSuccess)
				if response.body == 'true'
					return true
				end
			end

			return false
		end

		def fallback(e)
			logger.error("hystrix-ruby: failed to connect to remote for /allow: " + e.message)
			raise e
		end
	end
end
