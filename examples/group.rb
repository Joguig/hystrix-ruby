require_relative '../lib/hystrix.rb'

class CommandGroup < Hystrix::Command
  def run
    puts "Pool: #{executor_pool_name}"
  end
end

class CommandAppleGroup < CommandGroup
  group :apple
end

class CommandOrangeGroup < CommandGroup
  group :orange
end


puts CommandGroup.new.execute
puts CommandAppleGroup.new.execute
puts CommandOrangeGroup.new.execute
