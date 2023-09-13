require 'spec_helper'

describe Hystrix::CommandMetrics do
	subject(:metrics) do
		Hystrix::CommandMetrics.new("key", {})
	end

	describe :calculate_snapshot do
		let(:now) { Time.now }
		let(:total) { 2 }

		before do
			allow(metrics.wrapped_object).to receive(:rolling_total_count) { total }
			allow(metrics.wrapped_object).to receive(:rolling_error_count) { error }
		end

		context 'zero errors' do
			let(:error) { 0 }

			it 'returns 0 error percent' do
				Timecop.freeze(now) do
					expect(metrics.send(:calculate_snapshot)).to eq({
						time: now,
						total: 2,
						error: 0,
						error_percentage: 0
					})
				end
			end
		end

		context 'non-zero errors' do
			let(:error) { 1 }
			it 'returns correct percent' do
				Timecop.freeze(now) do
					expect(metrics.send(:calculate_snapshot)).to eq({
						time: now,
						total: 2,
						error: 1,
						error_percentage: 50
					})
				end
			end
		end
	end

	describe 'counts' do
		let(:counter) { double(Hystrix::RollingNumber) }
		let(:counts) { {failure: 1, timeout: 2, short_circuit: 3, success: 4, pool_full: 5} }

		before do
			allow(counter).to receive(:counts) { counts }
			allow(metrics.wrapped_object).to receive(:counter) { counter }
		end

		describe :rolling_total_count do
			context 'all counts present' do
				it 'sums all counts' do
					expect(metrics.send(:rolling_total_count)).to eq(15)
				end
			end

			context 'some counts missing' do
				let(:counts) { {success: 2, short_circuit: 3} }
				it 'sums present counts' do
					expect(metrics.send(:rolling_total_count)).to eq(5)
				end
			end
		end

		describe :rolling_error_count do
			context 'all counts present' do
				it 'sums all errors' do
					expect(metrics.send(:rolling_error_count)).to eq(11)
				end
			end

			context 'some counts missing' do
				let(:counts) { {success: 2, short_circuit: 3} }
				it 'sums present errors' do
					expect(metrics.send(:rolling_error_count)).to eq(3)
				end
			end
		end
	end
end
