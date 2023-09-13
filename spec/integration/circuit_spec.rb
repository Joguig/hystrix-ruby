require 'spec_helper'

describe Hystrix::Circuit do
  let(:metrics) do
    Hystrix::CommandMetrics.new("key",
      num_buckets: 3,
      window_len: 0.99,
      snapshot_inteval: 0.49,
    )
  end

  subject(:circuit) do
    Hystrix::Circuit.new("key", {
      sleep_window_in_milliseconds: 990,
      error_threshold: 0.3,
      min_requests: 2
    }, metrics)
  end

  describe 'health snapshot' do
    it 'checks a snapshot' do
      metrics.counter.increment(:failure)
      Timecop.freeze(Time.now + 1) do
        expect(circuit.allow_request?).to be_true
      end
    end

    it 'checks a snapshot' do
      Timecop.freeze(Time.now) do
        metrics.counter.increment(:failure)
        metrics.counter.increment(:failure)
        expect(circuit.allow_request?).to be_true
      end
    end

    it 'updates the snapshot' do
      metrics.counter.increment(:failure)
      metrics.counter.increment(:failure)
      Timecop.freeze(Time.now + 1) do
        expect(circuit.allow_request?).to be_false
      end
    end

    it 'allows a single_request after sleep window' do
      metrics.counter.increment(:failure)
      metrics.counter.increment(:failure)
      now = Time.now
      Timecop.freeze(now + 0.5) do
        circuit.open?
        Timecop.freeze(now + 1.5) do
          expect(circuit.allow_request?).to be_true
          expect(circuit.allow_request?).to be_false
        end
      end
    end
  end
end
