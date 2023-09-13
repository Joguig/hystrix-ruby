require 'spec_helper'

describe Hystrix::Command do
	after do
		Hystrix::Notifications.reset!
	end

	class CommandHelloWorld < Hystrix::Command
		attr_accessor :string, :wait, :fail

		def initialize(string, wait = 0, fail = false)
			self.string = string
			self.fail = fail
			self.wait = wait
			super
		end

		def run
			sleep wait

			if fail
				abort 'error'
			else
				return self.string
			end
		end

		def fallback(error)
			return 'it failed'
		end
	end

	class CommandLocalCircuit < Hystrix::Command
		circuit_breaker(force_local: true)

		def run; end
		def fallback(error); end
	end

	before do
		Hystrix::Circuit.reset!
	end

	context 'when remote mode is enabled' do
		before do
			Hystrix.remote = true
			Hystrix.port = 9999
		end

		after do
			Hystrix.remote = false
			Hystrix.port = nil
		end

		context 'using a simple command' do
			before do
				@cmd = CommandHelloWorld.new ''
			end

			it 'instantiates a remote circuit' do
				@cmd.circuit.is_a?(Hystrix::RemoteCircuit).should == true
			end
		end

		context 'using a command with a forced local circuit' do
			before do
				@cmd = CommandLocalCircuit.new
			end

			it 'instantiates a local circuit' do
				@cmd.circuit.is_a?(Hystrix::Circuit).should == true
			end
		end
	end

	context 'with a circuit, ' do
		before do
			@cmd = CommandHelloWorld.new 'circuit string'
			@circuit_mock = double('Hystrix::Circuit')
			@circuit_mock.stub(:async).and_return(@circuit_mock)
			@cmd.wrapped_object.stub(:circuit).and_return(@circuit_mock)
		end

		context 'when the circuit is closed, ' do
			before do
				@circuit_mock.stub(:allow_request?).and_return(true)
				allow(@circuit_mock).to receive(:report_event).with(:success, anything, anything)
			end

			it 'allows commands to succeed' do
				@cmd.execute.should == 'circuit string'
			end
		end

		context 'when the circuit is open, ' do
			before do
				@circuit_mock.stub(:is_closed?).and_return(false)
				allow(@circuit_mock).to receive(:report_event).with(:failure, anything, anything)
			end

			it 'triggers fallback responses' do
				@cmd.execute.should == 'it failed'
			end

			it 'does not attempt to run the command' do
				@cmd.wrapped_object.should_not_receive(:run)
			end
		end
	end

	context 'notifies callbacks,' do
		it 'on success' do
			test_name = nil
			test_duration = nil
			test_events = nil

			Hystrix.configure do
				subscribe do |command_name, duration, events|
					test_name = command_name
					test_duration = duration
					test_events = events
				end
			end

			CommandHelloWorld.new('keith').execute

			test_name.should == 'CommandHelloWorld'
			test_duration.should > 0
			test_events.should == [:success]
		end

		it 'on fallback' do
			test_name = nil
			test_duration = nil
			test_events = nil

			Hystrix.configure do
				subscribe do |command_name, duration, events|
					test_name = command_name
					test_duration = duration
					test_events = events
				end
			end

			CommandHelloWorld.new('keith', 0, true).execute

			test_name.should == 'CommandHelloWorld'
			test_duration.should > 0
			test_events.should == [:failure, :fallback_success]
		end

		it 'on failure' do
			test_name = nil
			test_duration = nil
			test_events = nil

			Hystrix.configure do
				subscribe do |command_name, duration, events|
					test_name = command_name
					test_duration = duration
					test_events = events
				end
			end

			class NoFallbackCommand < Hystrix::Command
				def run
					raise 'fail'
				end
			end

			expect {
				NoFallbackCommand.new.execute
			}.to raise_error

			test_name.should == "NoFallbackCommand"
			test_duration.should > 0
			test_events.should == [:failure]
		end

		it 'on fallback failure' do
			test_name = nil
			test_duration = nil
			test_events = nil

			Hystrix.configure do
				subscribe do |command_name, duration, events|
					test_name = command_name
					test_duration = duration
					test_events = events
				end
			end

			class CommandWithFailingFallback < Hystrix::Command
				def run
					raise 'run'
				end

				def fallback(error)
					raise 'fallback'
				end
			end

			expect {
				CommandWithFailingFallback.new.execute
			}.to raise_error

			test_name.should == "CommandWithFailingFallback"
			test_duration.should > 0
			test_events.should == [:failure, :fallback_failure]
		end

		it 'on timeout' do
			test_name = nil
			test_duration = nil
			test_events = nil

			Hystrix.configure do
				subscribe do |command_name, duration, events|
					test_name = command_name
					test_duration = duration
					test_events = events
				end
			end

			class TimeoutCmd < Hystrix::Command
				timeout_in_milliseconds 50
				def run
					sleep 1000
				end
			end

			expect { 
				TimeoutCmd.new.execute 
			}.to raise_error(Celluloid::Task::TimeoutError)

			test_name.should == "TimeoutCmd"
			test_duration.should > 0
			test_events.should == [:timeout]
		end
	end

	it 'allows commands to define their pool size' do
		class SizedPoolCommand < Hystrix::Command
			pool_size 3
		end

		cmd = SizedPoolCommand.new
		cmd.executor_pool.size.should == 3
	end

	context '.execute' do
		it 'supports sychronous execution' do
			CommandHelloWorld.new('keith').execute.should == 'keith'
		end

		it 'returns fallback value on error' do
			CommandHelloWorld.new('keith', 0, true).execute.should == 'it failed'
		end

		it 'sends exception to fallback method on error' do
			c = CommandHelloWorld.new('keith', 0, true)
			c.wrapped_object.should_receive(:fallback).with do |error|
				error.message.should == 'error'
			end
			c.execute
		end
	end	

	context '.queue' do
		it 'supports asynchronous execution' do
			CommandHelloWorld.new('keith').queue.value.should == 'keith'
		end

		it 'returns fallback value on error' do
			CommandHelloWorld.new('keith', 0, true).queue.value.should == 'it failed'
		end	
	end

	it 'can execute only once' do
		c = CommandHelloWorld.new('keith')
		c.execute.should == 'keith'
		expect { c.execute }.to raise_error
		expect { c.queue.value }.to raise_error
	end

	context 'when no fallback is defined' do
		before do
			class CommandWithNoFallback < Hystrix::Command
				def run
					abort 'the error'
				end
			end
		end
		it 'raises the original exception' do
			expect { CommandWithNoFallback.new.execute }.to raise_error('the error')
		end
	end

	it 'executes the fallback if it unable to grab an executor to run the command' do
		pool = Hystrix::CommandExecutorPool.new('my pool', 1)

		c1 = CommandHelloWorld.new('foo', 1)
		c1.executor_pool = pool
		c2 = CommandHelloWorld.new('bar')
		c2.executor_pool = pool

		future = c1.queue
		c2.execute.should == 'it failed'
		future.value.should == 'foo'
	end

	it 'throws an error if a command class does not run the base initialize method' do
		class Cmd < Hystrix::Command
			def initialize; end
			def run; end
		end

		expect {
			Cmd.new.execute
		}.to raise_error
	end

	it 'sends the correct error to the fallback if the abort celluloid method is used' do
		class AbortErrorCmd < Hystrix::Command
			attr_accessor :expected
			def initialize(str)
				self.expected = str
				super
			end
			def run
				abort self.expected
			end
			def fallback(e)
				return e.message == expected
			end
		end

		AbortErrorCmd.new("celluloid abort").execute.should == true
	end
end
