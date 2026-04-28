#!/usr/bin/env ruby

# Why does this script fail??

require "bundler/setup"
require "async"

$log = Queue.new

$log << "main fiber is #{Fiber.current}"

puts "Main thread #{Thread.current}"

at_exit do
  puts "exiting"
  sleep 5
  puts $log.pop until $log.empty?
  puts "done printing log"
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

    $log << "scheduler created in #{Fiber.current}"
    main_fiber = Fiber.current

    @idle_fiber = Fiber.new(blocking: false) do
      $log << "scheduler fiber is #{Fiber.current}"
      puts "Scheduler thread #{Thread.current}"

      loop do
        # $log << "ready fiber count #{@ready_fibers.size}"
        now = Time.now

        remove = []

        wake_at.each do |pair|
          if pair.first <= now
            $log << "Waking ##{pair.last}"
            remove << pair
            ready_fibers << pair.last
          end
        end

        unless remove.empty?
          remove.each do |pair|
            wake_at.delete(pair)
          end
          next
        end

        if @ready_fibers.empty? && @wake_at.empty? && @closing
          puts "breaking"
          $log << "breaking"
          break
        end

        # puts "idle fiber yielding back"
        if @ready_fibers.empty?
          @running = false

          if @closing
            # just transfer to all remaining waiting fibers
            unless @wake_at.empty?
              sleep 0.1
            end
          elsif @wait_until_all_done
            $log << "sleeping to wait for stuff to wake up"
            sleep 0.1
          else
            $log << "Transferring to main #{main_fiber}"
            main_fiber.transfer
          end
        else
          @running = true
          fiber = @ready_fibers.pop

          if fiber.alive?
            $log << "Transferring to #{fiber}"
            fiber.transfer
            $log << "control returned from #{fiber}?"
          else
            $log << "Whoa, #{fiber} is dead"
          end
        end
      end
    end

    @idle_fiber.transfer
  end

  def running? = @running

  def block(blocker, timeout = nil)
    raise if Fiber.current == @idle_fiber
    raise if timeout

    $log << "block called #{Fiber.current}"

    @idle_fiber.transfer

    true
  end

  def run_some_other_fiber
    # $log << "idle fiber is #{@idle_fiber}"
    # $log << "current fiber is #{Fiber.current}"

    # how is this called across threads??
    # Maybe this is why Async uses a pipe to wake things up instead of transfer?
    @idle_fiber.transfer
  end

  def unblock(blocker, fiber)
    raise if Fiber.current == @idle_fiber

    $log << "unblock called #{Fiber.current} for #{fiber}"
    @ready_fibers << fiber

    run_some_other_fiber unless running?
  end

  def close
    # if !@ready_fibers.empty? || !@wake_at.empty?
    #   $log << "wtf!!"
    #   $log << caller_locations
    # end

    $log << "closing!!"
    @closing = true
    @idle_fiber.transfer while @idle_fiber.alive?
  end

  def wait_until_all_fibers_done
    @wait_until_all_done = true
    $log << "transferring control to the scheduler from #{Fiber.current}"
    @idle_fiber.transfer until nothing_to_do?
  ensure
    @wait_until_all_done = false
  end

  def nothing_to_do?
    !@idle_fiber.alive? || (@ready_fibers.empty? && @wake_at.empty?)
  end

  def kernel_sleep(duration = nil)
    return if Fiber.current == @idle_fiber

    $log << "kernel_sleep called #{Fiber.current}"

    if duration
      @wake_at << [Time.now + duration, Fiber.current]
    end

    @idle_fiber.transfer
  end

  def io_wait(io, events, timeout)
    raise NotImplementedError
  end

  def fiber(&)
    fiber = Fiber.new(blocking: false, &)

    $log << "created #{fiber} from #{Fiber.current}"

    @ready_fibers << fiber

    fiber
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

f1 = Fiber.schedule do
  puts "f1 thread is #{Thread.current}"
  $log << "f1 is #{Fiber.current}"
  $log << "printing 1.1"
  puts 1.1
  sleep 5
  $log << "printing 1.2"
  puts 1.2
  $log << "printing 1.3"
  puts 1.3
end

f2 = Fiber.schedule do
  $log << "f2 is #{Fiber.current}"
  $log << "printing 2.1"
  puts 2.1
  $log << "printing 2.2"
  puts 2.2
  $log << "printing 2.3"
  puts 2.3
end

f3 = Fiber.schedule do
  $log << "f3 is #{Fiber.current}"
  $log << "printing 3.1"
  puts 3.1
  $log << "printing 3.2"
  puts 3.2
  $log << "printing 3.3"
  puts 3.3
end

$log << "main 1"
puts "main 1"

# [f1, f2, f3].each(&:resume)
# sleep 5
scheduler.close
puts "main 2"
$log << "main 2"
sleep 5
$log << "main 3"

# sleep 2
#
# scheduler.resume(f1)
#
# sleep 2
# scheduler.wait
