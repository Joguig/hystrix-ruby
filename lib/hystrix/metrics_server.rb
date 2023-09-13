require 'sinatra'

module Hystrix
	class MetricsServer < Sinatra::Base
		def initialize
			@calculator = MetricsCalculator.new
			@calculator.start
			super
		end

		get '/' do
			stream(:keep_open) do |out|
				@calculator.add(out)
			end
		end
	end

	class MetricsCalculator
		include Celluloid

		def initialize
			@listeners = []
		end

		def add(stream)
			@listeners << stream
		end

		def start
			every(1) { publish_metrics }
		end

		def publish_metrics
			@listeners.reject!(&:closed?)

			for out in @listeners
				for cb in circuit_metrics
					out << "data: " + cb.to_json + "\n\n"
				end
			end
		end

		def circuit_metrics
			metrics = []

			for name, cb in Circuit.all
				snapshot = cb.metrics.health_snapshot
				counts = cb.metrics.counter.counts

				metrics << {
					'Type'           => "HystrixCommand",
					'Name'           => name,
					'Group'          => name,
					'Time'           => (Time.now.to_f * 1000).to_i,
					'ReportingHosts' => 1,

					'requestCount'         => snapshot[:total],
					'errorCount'           => snapshot[:error],
					'errorPercentage'      => snapshot[:error_percentage],
					'isCircuitBreakerOpen' => cb.open?,

					'rollingCountSuccess'            => counts[:success] || 0,
					'rollingCountFailure'            => counts[:failure] || 0,
					'rollingCountShortCircuited'     => counts[:short_circuit] || 0,
					'rollingCountThreadPoolRejected' => counts[:pool_full] || 0,
					'rollingCountTimeout'            => counts[:timeout] || 0,

					# not implemented
					'rollingCountSemaphoreRejected'   => 0,
					'rollingCountCollapsedRequests'   => 0,
					'rollingCountExceptionsThrown'    => 0,
					'rollingCountFallbackFailure'     => 0,
					'rollingCountFallbackRejection'   => 0,
					'rollingCountFallbackSuccess'     => 0,
					'rollingCountResponsesFromCache'  => 0,
					'currentConcurrentExecutionCount' => 0,

					'latencyExecute_mean' => cb.metrics.execute_timing.mean,
					'latencyExecute'      => cb.metrics.execute_timing.timings,
					'latencyTotal_mean'   => cb.metrics.total_timing.mean,
					'latencyTotal'        => cb.metrics.total_timing.timings,

					'propertyValue_circuitBreakerRequestVolumeThreshold'             => 0,
					'propertyValue_circuitBreakerSleepWindowInMilliseconds'          => 0,
					'propertyValue_circuitBreakerErrorThresholdPercentage'           => 0,
					'propertyValue_circuitBreakerForceOpen'                          => false,
					'propertyValue_circuitBreakerForceClosed'                        => false,
					'propertyValue_circuitBreakerEnabled'                            => true,
					'propertyValue_executionIsolationStrategy'                       => 'THREAD',
					'propertyValue_executionIsolationThreadTimeoutInMilliseconds'    => 0,
					'propertyValue_executionIsolationThreadInterruptOnTimeout'       => false,
					'propertyValue_executionIsolationThreadPoolKeyOverride'          => 0,
					'propertyValue_executionIsolationSemaphoreMaxConcurrentRequests' => 0,
					'propertyValue_fallbackIsolationSemaphoreMaxConcurrentRequests'  => 0,
					'propertyValue_metricsRollingStatisticalWindowInMilliseconds'    => 0,
					'propertyValue_requestCacheEnabled'                              => false,
					'propertyValue_requestLogEnabled'                                => false,
				}
			end

			return metrics
		end
	end
end