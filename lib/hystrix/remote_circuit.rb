require 'hystrix/remote/commands'

module Hystrix
	class RemoteCircuit < Circuit
		def initialize(key, opts, metrics)
			super

			@remote = false
			@remote_timer = every(10) { check_connection }
			self.async.start # start circuit asynchronously to prevent deadlock. (start creates circuits itself)
		end

		def start
			@remote = RegisterRemoteCircuit.new(@key, @sleep_window, @error_threshold, @min_requests).execute	
		end

		def check_connection
			success = CheckRemoteConnection.new.execute

			# if the remote circuit restarts, we need to re-register our circuit settings
			if !@remote and success
				self.start
			end

			@remote = success
		end

		def report_event(type, start_time, run_duration)
			return super unless @remote

			success = ReportRemoteEvent.new(@key, type, start_time, run_duration).execute
			if !success
				@remote = false
			end
		end

		def allow_request?
			return super unless @remote

			begin
				allowed = AllowRemoteRequest.new(@key).execute	
			rescue Exception => e
				# if we have an issue talking to the remote circuit (like a timeout) we should let the request through
				# since there is no evidence that the backend service is unhealthy.  switching to local mode will begin
				# measuring actual service health.
				@remote = false
				return true
			end

			return allowed
		end
	end
end