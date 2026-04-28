#!/usr/bin/env ruby

# Why does this script fail??

require "bundler/setup"
require "async"

$log = Queue.new

$log << "main fiber is #{Fiber.current}"

at_exit do
  puts $log.pop until $log.empty?
end

# require "pry"
# require "pry-byebug"

# scheduler = Async::Scheduler.new
# Fiber.set_scheduler(scheduler)

class MyFiberScheduler
  def initialize
    @scheduler_thread = Thread.current

    wake_at = @wake_at = []
    ready_fibers = @ready_fibers = Queue.new

    $log << "schduler created in #{Fiber.current}"

    @idle_fiber = Fiber.new(blocking: false) do
      $log << "scheduler fiber is #{Fiber.current}"
      loop do
        now = Time.now

        remove = []

        wake_at.each do |pair|
          if pair.first <= now
            remove << pair
            ready_fibers << pair.second
          end
        end

        remove.each do |pair|
          wake_at.delete(pair)
        end

        # puts "idle fiber yielding back"
        if @ready_fibers.empty?
          @running = false

          sleep 0.1
        else
          @running = true
          @ready_fibers.pop.transfer
        end
      end
    end
  end

  def running? = @running

  def block(blocker, timeout = nil)
    $log << "block called #{Fiber.current}"
    # whoops, seems this can be called from another thread?? Definitely don't want to "resume" if that happens?
    @running = false
  end

  def run_some_other_fiber
    # $log << "idle fiber is #{@idle_fiber}"
    # $log << "current fiber is #{Fiber.current}"

    # how is this called across threads??
    # Maybe this is why Async uses a pipe to wake things up instead of transfer?
    @idle_fiber.transfer
  end

  def unblock(blocker, fiber)
    $log << "unblock called #{Fiber.current} for #{fiber}"
    @ready_fibers << fiber

    run_some_other_fiber unless running?
  end

  def kernel_sleep(duration = nil)
    $log << "kernel_sleep called #{Fiber.current}"

    if duration
      @wake_at << [Time.now + duration, Fiber.current]
    end
  end

  def io_wait(io, events, timeout)
    raise NotImplementedError
  end

  def fiber(&)
    Fiber.new(blocking: false, &).tap(&:resume)
  end

  def fiber_interrupt(fiber, exception)
    raise NotImplementedError
  end
end

scheduler = MyFiberScheduler.new
Fiber.set_scheduler(scheduler)

# Thread.new do
#   100_000.times { puts it }
# end

sleep 0.1

f1 = Fiber.schedule do
  $log << "f1 is #{Fiber.current}"
  puts 1.1
  sleep 1
  puts 1.2
  puts 1.3
end

f2 = Fiber.schedule do
  $log << "f2 is #{Fiber.current}"
  puts 2.1
  puts 2.2
  puts 2.3
end

f3 = Fiber.schedule do
  $log << "f3 is #{Fiber.current}"
  puts 3.1
  puts 3.2
  puts 3.3
end

sleep 2

# [f1, f2, f3].each(&:resume)

# sleep 2
#
# scheduler.resume(f1)
#
# sleep 2
# scheduler.wait
