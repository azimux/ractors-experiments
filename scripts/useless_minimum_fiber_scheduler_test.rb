#!/usr/bin/env ruby

# The goal here is to see if we can make a scheduler that doesn't require a Fiber to coordinate stuff

require "bundler/setup"

$log = Queue.new

$log << "main fiber is #{Fiber.current}"

at_exit do
  puts "exiting"
  # puts $log.pop until $log.empty?
  puts "done printing log"
end

# require "pry"
# require "pry-byebug"

class MyFiberScheduler
  module FiberSchedulerInterface
    def block(blocker, timeout = nil)
      $log << "block called #{Fiber.current} by #{blocker} #{timeout}"
      # return false if block can't be implemented
      false
    end

    def unblock(blocker, fiber)
      $log << "unblock called for #{fiber} in #{Fiber.current}"
    end

    def kernel_sleep(duration = nil)
      $log << "kernel_sleep called #{Fiber.current}"

      now = t0 = Time.now

      if duration
        # A really bad sleep implementation!
        now = Time.now until now - t0 >= duration
        true
      else
        raise NotImplementedError
      end
    end

    def fiber(&)
      f = Fiber.new(&)
      fibers << f

      $log << "created #{f} from #{Fiber.current}"

      f
    end

    def fiber_interrupt(fiber, exception) = raise NotImplementedError
    def io_wait(...) = raise NotImplementedError
    def io_read(...) = raise NotImplementedError
    # This method is considered experimental and seems to be ignored if we don't #respond_to? it
    # def io_write(...) = raise NotImplementedError
    def io_pread(...) = raise NotImplementedError
    def io_pwrite(...) = raise NotImplementedError
    def io_select(...) = raise NotImplementedError
    def io_close(...) = raise NotImplementedError
    def process_wait(...) = raise NotImplementedError
    def timeout_after(...) = raise NotImplementedError
    def address_resolve(...) = raise NotImplementedError
    def blocking_operation_wait(...) = raise NotImplementedError
    def yield(...) = raise NotImplementedError

    def close
      $log << "Close called"

      until fibers.empty?
        fibers.dup.each do |fiber|
          if fiber.alive?
            fiber.transfer
          else
            fibers.delete(fiber)
          end
        end
      end
    end
  end

  include FiberSchedulerInterface

  attr_accessor :fibers

  def initialize
    self.fibers = []
    $log << "scheduler created in #{Fiber.current}"
  end
end

class Integer
  def factorial = self <= 1 ? 1 : self * (self - 1).factorial
end

puts "here we go!!"

scheduler = MyFiberScheduler.new
Fiber.set_scheduler(scheduler)

$log << "#{Time.now.inspect} creating Thread or Ractor"

factorial_thread_or_ractor = Thread.new do
  $log << "#{Time.now.inspect} factorial thread starting"

  100.times do |i|
    i = i.factorial
    puts i
    # sleep 0
    # $log << i
  end

  $log << "#{Time.now.inspect} factorial thread done"
end

# sleep 0

$log << "#{Time.now.inspect} creating fibers"

f1 = Fiber.schedule do
  $log << "f1 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 1.1"
  puts 1.1
  sleep 1
  $log << "#{Time.now.inspect} puts 1.2"
  puts 1.2
  $log << "#{Time.now.inspect} puts 1.3"
  puts 1.3
end

f2 = Fiber.schedule do
  $log << "f2 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 2.1"
  puts 2.1
  $log << "#{Time.now.inspect} puts 2.2"
  puts 2.2
  $log << "#{Time.now.inspect} puts 2.3"
  puts 2.3
end

f3 = Fiber.schedule do
  $log << "f3 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 3.1"
  puts 3.1
  $log << "#{Time.now.inspect} puts 3.2"
  puts 3.2
  $log << "#{Time.now.inspect} puts 3.3"
  puts 3.3
end

$log << "main 1"
puts "main 1"

f4 = Fiber.schedule do
  $log << "f4 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 4.1"
  puts 4.1
  sleep 2
  $log << "#{Time.now.inspect} puts 4.2"
  puts 4.2
  $log << "#{Time.now.inspect} puts 4.3"
  puts 4.3
end

f5 = Fiber.schedule do
  $log << "f5 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 5.1"
  puts 5.1
  $log << "#{Time.now.inspect} puts 5.2"
  puts 5.2
  $log << "#{Time.now.inspect} puts 5.3"
  puts 5.3
end

f6 = Fiber.schedule do
  $log << "f6 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 6.1"
  puts 6.1
  $log << "#{Time.now.inspect} puts 6.2"
  puts 6.2
  $log << "#{Time.now.inspect} puts 6.3"
  puts 6.3
end

$log << "#{Time.now.inspect} done creating fibers"

scheduler.close

puts "main 2"
$log << "main 2"

factorial_thread_or_ractor.join

puts "main 3"
$log << "main 3"
