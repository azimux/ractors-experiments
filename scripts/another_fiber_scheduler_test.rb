#!/usr/bin/env ruby

# The goal here is to see if we can make a scheduler that doesn't require a Fiber to coordinate stuff

require "bundler/setup"

$log = Queue.new

$log << "main fiber is #{Fiber.current}"

at_exit do
  puts "exiting"
  puts $log.pop until $log.empty?
  puts "done printing log"
end

# require "pry"
# require "pry-byebug"

class MyFiberScheduler
  module FiberSchedulerInterface
    def block(blocker, timeout = nil)
      $log << "block called #{Fiber.current} by #{blocker} #{timeout}"

      fiber = Fiber.current

      if timeout
        blocked_until[fiber] = Time.now + timeout
      else
        blocked << fiber
      end

      transfer

      true
    end

    # This might be called from a different thread! wow! Is this threadsafe to use Array across
    # threads like this??
    def unblock(blocker, fiber)
      $log << "unblock called for #{fiber} in #{Fiber.current}"

      blocked.delete(fiber)

      if Thread.current == scheduler_thread
        transfer
      else
        # This is important! If we are in a different thread, we cannot transfer control to the fiber.
        # What we can do though is sleep the other thread to give ourselves a chance to run
        sleep 0
      end
    end

    def kernel_sleep(duration = nil)
      fiber = Fiber.current

      $log << "kernel_sleep called #{fiber}"

      if duration
        blocked_until[fiber] = Time.now + duration
        transfer
      else
        raise NotImplementedError
      end
    end

    def fiber(&)
      fiber = Fiber.new(&)
      fibers << fiber

      $log << "created #{fiber} from #{Fiber.current}"

      fiber
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
      @closing = true

      $log << "Close called"

      transfer until fibers.empty?

      created_in_fiber.transfer
    end
  end

  include FiberSchedulerInterface

  attr_accessor :fibers, :blocked, :blocked_until, :created_in_fiber, :fibers_index, :scheduler_thread

  def initialize
    self.created_in_fiber = Fiber.current
    self.fibers = [created_in_fiber]
    self.fibers_index = 0
    self.blocked = []
    self.blocked_until = {}
    self.scheduler_thread = Thread.current

    $log << "scheduler created in #{Fiber.current}"
  end

  def transfer
    until fibers.empty?
      self.fibers_index += 1
      self.fibers_index %= fibers.size

      fiber = fibers[fibers_index]

      unless fiber.alive?
        fibers.delete(fiber)
        self.fibers_index -= 1
        next
      end

      next if blocked.include?(fiber)

      if closing? && fiber == created_in_fiber
        fibers.delete(fiber)
        self.fibers_index -= 1
        next
      end

      if blocked_until.key?(fiber)
        if blocked_until[fiber] >= Time.now
          next
        else
          blocked_until.delete(fiber)
        end
      end

      fiber.transfer

      return
    end

    created_in_fiber.transfer
  end

  def closing? = @closing
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
