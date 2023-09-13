require 'spec_helper'

describe Hystrix::RollingTiming do
  subject(:timing) { Hystrix::RollingTiming.new(10) }

	context 'new rolling number' do
    it 'has a 0 mean' do
      expect(timing.mean).to eq(0)
    end

    it 'calculates ordinals' do
      sets = [
        [1, 0, 1],
        [2, 0, 1],
        [2, 50, 1],
        [2, 51, 2],
        [5, 30, 2],
        [5, 40, 2],
        [5, 50, 3],
        [11, 25, 3],
        [11, 50, 6],
        [11, 75, 9],
        [11, 100, 11]
      ]

      for s in sets
        expect(Hystrix::RollingTiming.ordinal(s[0], s[1])).to eq(s[2])
      end
    end

    it 'can have timings added' do
      timing.add(100)
      timing.add(200)

      expect(timing.mean).to eq(150)
    end

    it 'sorts added durations' do
      timing.add(200)
      timing.add(100)

      Timecop.freeze(Time.now + 1.5) do
        timing.add(50)
        timing.add(150)

        expect(timing.sorted_durations).to eq([50, 100, 150, 200])
      end
    end

    it 'calculates timings across buckets' do
      timing.add(100)
      timing.add(200)

      Timecop.freeze(Time.now + 1.5) do
        timing.add(300)
        timing.add(400)

        expect(timing.timings['75']).to eq(300)
      end
    end

    it 'calculates percentiles' do
      durations = [1, 1004, 1004, 1004, 1004, 1004, 1004, 1004, 1004, 1004, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1005, 1006, 1006, 1006, 1006, 1007, 1007, 1007, 1008, 1015]
      for d in durations
        timing.add(d)
      end

      expect(timing.percentile(0)).to eq(1)
      expect(timing.percentile(75)).to eq(1006)
      expect(timing.percentile(99)).to eq(1015)
      expect(timing.percentile(100)).to eq(1015)
    end
  end
end
