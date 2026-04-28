#!/usr/bin/env ruby

# Why does this script fail??

require "bundler/setup"
require "async"

# require "pry"
# require "pry-byebug"

scheduler = Async::Scheduler.new
scheduler.run
Fiber.set_scheduler(scheduler)

f1 = Fiber.new do
  puts 1.1
  sleep 1
  puts 1.2
  puts 1.3
end

f2 = Fiber.new do
  puts 2.1
  puts 2.2
  puts 2.3
end

f3 = Fiber.new do
  puts 3.1
  puts 3.2
  puts 3.3
end

sleep 2

[f1, f2, f3].each(&:resume)

sleep 2
# uncommenting this line makes it work, strange!
# scheduler.resume(f1)
