require 'spec_helper'

describe Hystrix::Notifications do
	it 'defines callbacks via dsl' do
		Hystrix.configure do
			subscribe do |name, duration, events|
				raise 'callback'
			end
		end

		expect {
			Hystrix::Notifications.publish('test', 30, [])
		}.to raise_error('callback')
	end
end
