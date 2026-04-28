#!/usr/bin/env ruby

# Why does this script fail??

require "bundler/setup"
# require "async"

$log = Queue.new

$log << "main fiber is #{Fiber.current}"
$main_fiber = Fiber.current

at_exit do
  puts "exiting"
  puts $log.pop until $log.empty?
  puts "done printing log"
end

# require "pry"
# require "pry-byebug"

# scheduler = Async::Scheduler.new
# Fiber.set_scheduler(scheduler)

class MyFiberScheduler
  def initialize
    @wake_at = []
    @ready_fibers = Queue.new

    $log << "scheduler created in #{Fiber.current}"
    main_fiber = Fiber.current

    @idle_fiber = Fiber.new do
      $log << "scheduler fiber is #{Fiber.current}"

      loop do
        # $log << "ready fiber count #{@ready_fibers.size}"
        now = Time.now

        remove = []

        @wake_at.each do |pair|
          if pair.first <= now
            $log << "Waking ##{pair.last}"
            remove << pair
            @ready_fibers << pair.last
          end
        end

        unless remove.empty?
          remove.each { |pair| @wake_at.delete(pair) }
        end

        if @ready_fibers.empty? && @wake_at.empty? && @closing
          puts "breaking"
          $log << "breaking"
          break
        end

        # puts "idle fiber yielding back"
        if @ready_fibers.empty?
          if @closing
            # just transfer to all remaining waiting fibers
            unless @wake_at.empty?
              sleep 0.1
            end
          elsif @catching_up
            # $log << "sleeping to wait for stuff to wake up"
            sleep 0.1
          else
            $log << "Transferring to main #{main_fiber}"
            main_fiber.transfer
          end
        else
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

  def block(blocker, timeout = nil)
    raise if Fiber.current == @idle_fiber
    raise if timeout

    $log << "block called #{Fiber.current}"

    @idle_fiber.transfer

    true
  end

  def unblock(blocker, fiber)
    raise if Fiber.current == @idle_fiber

    $log << "unblock called #{Fiber.current} for #{fiber}"
    @ready_fibers << fiber

    @idle_fiber.transfer unless running?
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

  def catchup
    @catching_up = true
    $log << "transferring control to the scheduler from #{Fiber.current}"
    @idle_fiber.transfer until nothing_to_do?
  ensure
    @catching_up = false
  end

  def nothing_to_do?
    !@idle_fiber.alive? || (@ready_fibers.empty? && @wake_at.empty?)
  end

  # For whatever reason, this is called for the idle fiber but never for the main fiber hmmm... why?
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

$log << "main 1"
puts "main 1"

scheduler.catchup

f4 = Fiber.schedule do
  $log << "f4 is #{Fiber.current}"
  puts 4.1
  sleep 1
  puts 4.2
  puts 4.3
end

f5 = Fiber.schedule do
  $log << "52 is #{Fiber.current}"
  puts 5.1
  puts 5.2
  puts 5.3
end

f6 = Fiber.schedule do
  $log << "63 is #{Fiber.current}"
  puts 6.1
  puts 6.2
  puts 6.3
end

puts "main 2"
$log << "main 2"
