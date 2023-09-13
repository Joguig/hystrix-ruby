require_relative '../lib/hystrix.rb'

class CommandSlowWork < Hystrix::Command
	pool_size 3
	timeout 1

	attr_accessor :wait

	def initialize(wait = 0)
		self.wait = wait
		super
	end

	def run
		Kernel.sleep wait
		return "Did work"
	end

	def fallback(error)
		return 'Work took too long'
	end
end

class CommandNoTimeout < Hystrix::Command
	def run
		sleep 1
		return "no timeout"
	end
end

# Success!
puts CommandSlowWork.new(0).execute

# Timeout
puts CommandSlowWork.new(2).execute

# No Timeout
puts CommandNoTimeout.new.execute

# Inline Timeout
result = Hystrix.inline do
	timeout 2
	execute { Kernel.sleep 10; "Did work" }
	fallback { "Work took too long" }
end
puts result
