module Hystrix
	class Notifications
		@subscribers = []

		def self.subscribe(&block)
			@subscribers << block
		end

		def self.publish(name, duration, events)
			@subscribers.each do |callback|
				callback.call(name, duration, events)
			end
		end

		def self.reset!
			@subscribers = []
		end
	end
end
