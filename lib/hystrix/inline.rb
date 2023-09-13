module Hystrix
	class InlineDSL
		def initialize(group = nil)
			@cmd = InlineCommand.new(group)
			@mode = :execute
		end

		def execute(&block)
			@mode = :execute
			@run_block = block
		end

		def queue(&block)
			@mode = :queue
			@run_block = block
		end

		def fallback(&block)
			@fallback_block = block
		end

		def run
			@cmd.run_block = @run_block
			@cmd.fallback_block = @fallback_block
			@cmd.send(@mode)
		end

		def timeout_in_milliseconds(duration)
			@cmd.class.timeout_in_milliseconds(duration)
		end
	end

	class InlineCommand < Command
		attr_accessor :run_block, :fallback_block

		def initialize(group)
      self.class.group(group)
			super
		end

		def run
			# Ensure we bind the block to the Command object's scope
			# to match the behavior of the non-inline instantiation method
			# puts instance_eval(@run_block)
			instance_exec &@run_block
		end

		def fallback(error)
			if @fallback_block
				instance_exec error, &@fallback_block
			else
				raise NotImplementedError
			end
		end
	end
end
