require 'celluloid'

require 'hystrix/logging'
require 'hystrix/command'
require 'hystrix/notifications'
require 'hystrix/circuit'
require 'hystrix/dsl'
require 'hystrix/executor_pool'
require 'hystrix/inline'
require 'hystrix/command_metrics'
require 'hystrix/rolling_number'
require 'hystrix/rolling_timing'
require 'hystrix/remote_circuit'

module Hystrix
	extend DSL

	def self.reset
		CommandExecutorPools.instance.shutdown
	end

	@@remote = false
	def self.remote=(remote)
		@@remote = remote
	end

	def self.remote
		@@remote
	end

	def self.host=(host)
		@@host = host
	end

	def self.host
		@@host || "localhost"
	end

	def self.port=(port)
		@@port = port
	end

	def self.port
		@@port || "8000"
	end
end
