require 'spec_helper'

describe Hystrix::InlineDSL do
	context 'declares commands' do
		it 'synchronously' do
			foo = 'bar'

			thing = Hystrix.inline do
				execute { foo*2 }
			end

			thing.should == 'barbar'
		end

		it 'asynchronously' do
			thing = Hystrix.inline do
				queue { 2+2 }
			end

			thing.value.should == 4
		end

		it 'with fallbacks' do
			thing = Hystrix.inline do
				execute { raise 'woops' }
				fallback { |error| 'fallback' }
			end

			thing.should == 'fallback'
		end	
	end

	it 'sets the executor_pool_name for the block' do
		mock = double
		expect(mock).to receive(:check).with('sup')

		Hystrix.configure do
			subscribe do |command_name, duration|
				mock.check(command_name)
			end
		end

		thing = Hystrix.inline 'sup' do
			execute { 'hi' }
		end

		Hystrix::Notifications.reset!
	end

	it 'sets the command timeout' do
		Hystrix::Command.stub(:timeout_in_milliseconds)

		thing = Hystrix.inline do
			timeout_in_milliseconds 5000
			execute { 'hi' }
		end

		thing.should == 'hi'

		Hystrix::Command.should have_received(:timeout_in_milliseconds).with(5000)
	end

	it 'sets the command group' do
		Hystrix::Command.stub(:group)

		thing = Hystrix.inline 'cats' do
			execute { 'hi' }
		end

		thing.should == 'hi'

		Hystrix::Command.should have_received(:group).with("cats")
	end
end
