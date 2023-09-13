require 'spec_helper'

describe Hystrix::Circuit do
  let(:metrics) { double(Hystrix::CommandMetrics) }

  subject(:circuit) do
    Hystrix::Circuit.new("key", {}, metrics)
  end

  describe :allow_request? do
    context 'circuit is closed' do
      it 'allows request' do
        allow(circuit.wrapped_object).to receive(:closed?) { true }
        expect(circuit.allow_request?).to be_true;
      end
    end

    context 'circuit is half-open' do
      it 'allows first request' do
        allow(circuit.wrapped_object).to receive(:closed?) { false }
        allow(circuit.wrapped_object).to receive(:allow_single_request?) { true }
        expect(circuit.allow_request?).to be_true;
      end
    end

    context 'circuit is open' do
      it 'disallows requests' do
        allow(circuit.wrapped_object).to receive(:closed?) { false }
        allow(circuit.wrapped_object).to receive(:allow_single_request?) { false }
        expect(circuit.allow_request?).to be_false;
      end
    end
  end

  describe :should_open? do
    context 'not enough requests' do
      it "doesn't open" do
        allow(circuit.wrapped_object).to receive(:min_requests) { 5 }
        allow(metrics).to receive(:health_snapshot) { {total: 2} }
        expect(circuit.send(:should_open?)).to be_false;
      end
    end

    context 'not enough errors' do
      it "doesn't open" do
        allow(circuit.wrapped_object).to receive(:min_requests) { 5 }
        allow(circuit.wrapped_object).to receive(:error_threshold) { 0.2 }
        allow(metrics).to receive(:health_snapshot) { {total: 10, error_percentage: 0.1} }
        expect(circuit.send(:should_open?)).to be_false;
      end
    end

    context 'too enough errors' do
      it "opens" do
        allow(circuit.wrapped_object).to receive(:min_requests) { 5 }
        allow(circuit.wrapped_object).to receive(:error_threshold) { 0.2 }
        allow(metrics).to receive(:health_snapshot) { {total: 10, error_percentage: 0.3} }
        expect(circuit.send(:should_open?)).to be_true;
      end
    end
  end
end
