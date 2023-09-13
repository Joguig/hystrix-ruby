require 'spec_helper'

describe Hystrix::RollingNumber do
  subject(:number) { Hystrix::RollingNumber.new(3, 1) }

	context 'new rolling number' do
    it 'starts at 0' do
      expect(number.count(:foo)).to eq(0)
    end

    it 'can be incremented' do
      number.increment(:foo)
      expect(number.count(:foo)).to eq(1)

      number.increment(:foo)
      expect(number.count(:foo)).to eq(2)
    end

    it 'keeps separate counts by type' do
      number.increment(:foo)
      number.increment(:bar)

      expect(number.count(:foo)).to eq(1)
      expect(number.count(:bar)).to eq(1)
      expect(number.count(:baz)).to eq(0)
    end

    it 'sums all buckets in the rolling window' do
      number.increment(:foo)
      number.increment(:bar)
      Timecop.freeze(Time.now + 1.5) do
        number.increment(:bar)
        number.increment(:baz)

        vals = {foo: 1, bar: 2, baz: 1}
        expect(number.counts).to eq(vals)
      end
    end
  end

  context 'after the window length has passed' do
    it 'creates more buckets' do
      number

      Timecop.freeze(Time.now + 2.5) do
        expect(number.buckets.length).to eq(3)
      end
    end

    context 'if we are at max buckets' do
      it 'removes earlier buckets' do
        number.increment(:foo)
        now = Time.now

        Timecop.freeze(now + 1.5) do
          number.increment(:foo)

          Timecop.freeze(now + 3.5) do
            expect(number.count(:foo)).to eq(1)
          end

          Timecop.freeze(now + 4.5) do
            expect(number.count(:foo)).to eq(0)
          end
        end
      end
    end
  end
end
