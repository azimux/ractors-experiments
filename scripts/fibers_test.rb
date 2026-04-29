#!/usr/bin/env ruby

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
      return false if Fiber.current == @idle_fiber

      fiber = Fiber.current

      $log << "block called #{fiber} by #{blocker} #{timeout}"

      if timeout
        wake_at(timeout)
      else
        block_indefinitely
      end

      @idle_fiber.transfer

      true
    end

    def unblock(blocker, fiber)
      raise if Fiber.current == @idle_fiber

      $log << "unblock called for #{fiber} in #{Fiber.current}"

      if @blocked.key?(fiber)
        count = @blocked[fiber]
        count -= 1

        if count <= 0
          @blocked.delete(fiber)
          @ready_fibers << fiber
          wake_up
        end
      end

      return if running?

      if Thread.current == @scheduler_thread
        @idle_fiber.transfer
      else
        # This is important! If we are in a different thread, we cannot transfer control to the fiber.
        # What we can do though is sleep the other thread to give outselves a chance to run
        sleep 0
      end
    end

    def kernel_sleep(duration = nil)
      return if Fiber.current == @idle_fiber

      $log << "kernel_sleep called #{Fiber.current}"

      if duration
        wake_at(duration)
      else
        block_indefinitely
      end

      @idle_fiber.transfer
    end

    def fiber(&)
      fiber = Fiber.new(&)

      $log << "created #{fiber} from #{Fiber.current}"

      @ready_fibers << fiber

      wake_up

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
  end

  include FiberSchedulerInterface

  def initialize
    @scheduler_thread = Thread.current

    @wake_at = []
    @blocked = {}.compare_by_identity
    @ready_fibers = Queue.new
    @wakeup_queue = Queue.new

    $log << "wakeup queue is #{@wakeup_queue}"

    $log << "scheduler created in #{Fiber.current}"
    @main_fiber = Fiber.current

    @idle_fiber = Fiber.new do
      $log << "scheduler fiber is #{Fiber.current}"

      loop do
        if @ready_fibers.empty? && @wake_at.empty? && @closing
          $log << "breaking"
          @running = false
          break
        end

        tick_idle_fiber
      end
    end

    @idle_fiber.transfer
  end

  def tick_idle_fiber
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

    # puts "idle fiber yielding back"
    if @ready_fibers.empty?
      @running = false

      if @closing || @catching_up
        # just transfer to all remaining waiting fibers
        unless @wake_at.empty?
          @sleeping = true

          timeout = @wake_at.map(&:first).min - Time.now

          Thread.new(timeout, @wakeup_queue) do |timeout, queue|
            sleep timeout
            queue << true
          end

          @wakeup_queue.pop(timeout:)
          @wakeup_queue.clear
          $log << "waking up!!"
          @sleeping = false
        end
      else
        $log << "Transferring to main #{@main_fiber}"
        @main_fiber.transfer
      end
    else
      fiber = @ready_fibers.pop

      # TODO: the wake_at check is pretty bad, performance-wise
      if fiber.alive? && !@blocked.key?(fiber) && !@wake_at.map(&:last).include?(fiber)
        $log << "Transferring to #{fiber}"
        @running = true
        fiber.transfer
        $log << "control returned from #{fiber}?"
      else
        $log << "Whoa, #{fiber} is dead"
      end
    end
  end

  def running? = @running
  def sleeping? = @sleeping

  def close
    wake_up
    $log << "closing!!"
    @closing = true
    @idle_fiber.transfer while @idle_fiber.alive?
  end

  def catchup
    wake_up
    @catching_up = true
    $log << "transferring control to the scheduler from #{Fiber.current}"
    @idle_fiber.transfer until nothing_to_do?
  ensure
    @catching_up = false
  end

  def wake_up
    @wakeup_queue << true
  end

  def nothing_to_do?
    !@idle_fiber.alive? || (@ready_fibers.empty? && @wake_at.empty?)
  end

  # For whatever reason, this is called for the idle fiber but never for the main fiber hmmm... why?
  def wake_at(duration)
    fiber = Fiber.current

    entry = @wake_at.find { it.last == fiber }

    at = Time.now + duration

    if entry
      if entry.first > at
        entry[0] = at
        wake_up
      end
    else
      @wake_at << [at, fiber]
      wake_up
    end
  end

  def block_indefinitely
    fiber = Fiber.current

    count = @blocked[fiber] || 0
    @blocked[fiber] = count + 1
  end
end

class Integer
  def factorial
    if self <= 1
      1
    else
      self * (self - 1).factorial
    end
  end
end

scheduler = MyFiberScheduler.new
Fiber.set_scheduler(scheduler)

puts "here we go!!"

$log << "#{Time.now.inspect} creating Thread"

# Some strange outcomes based on which sleeps are commented out...
# sleep in factorial thread    sleep in main thread      outcome
#                         Y                       Y      everything interleaved as expected, slow until 4.3 printed
#                         Y                       N      everything interleaved as expected, slow until 4.3 printed
#                         N                       Y      factorial thread prints in entirety before fibers hmm
#                         N                       N      everything interleaved as expected, slow until 4.3 printed
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

# fiber_creation_method = :new
fiber_creation_method = :schedule

$log << "#{Time.now.inspect} creating fibers"

f1 = Fiber.send(fiber_creation_method) do
  $log << "f1 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 1.1"
  puts 1.1
  sleep 1
  $log << "#{Time.now.inspect} puts 1.2"
  puts 1.2
  $log << "#{Time.now.inspect} puts 1.3"
  puts 1.3
end

f2 = Fiber.send(fiber_creation_method) do
  $log << "f2 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 2.1"
  puts 2.1
  $log << "#{Time.now.inspect} puts 2.2"
  puts 2.2
  $log << "#{Time.now.inspect} puts 2.3"
  puts 2.3
end

f3 = Fiber.send(fiber_creation_method) do
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

f4 = Fiber.send(fiber_creation_method) do
  $log << "f4 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 4.1"
  puts 4.1
  sleep 2
  $log << "#{Time.now.inspect} puts 4.2"
  puts 4.2
  $log << "#{Time.now.inspect} puts 4.3"
  puts 4.3
end

f5 = Fiber.send(fiber_creation_method) do
  $log << "f5 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 5.1"
  puts 5.1
  $log << "#{Time.now.inspect} puts 5.2"
  puts 5.2
  $log << "#{Time.now.inspect} puts 5.3"
  puts 5.3
end

f6 = Fiber.send(fiber_creation_method) do
  $log << "f6 is #{Fiber.current}"
  $log << "#{Time.now.inspect} puts 6.1"
  puts 6.1
  $log << "#{Time.now.inspect} puts 6.2"
  puts 6.2
  $log << "#{Time.now.inspect} puts 6.3"
  puts 6.3
end

$log << "#{Time.now.inspect} done creating fibers"

if fiber_creation_method == :new
  # If the fibers are created with .new then we must manually start them. Otherwise if called with
  # .schedule they are handled in the scheduler's #fiber method.
  # It seems that the main practical difference that's noticeable at the moment is that calling
  # Fiber.schedule results in #fiber being called and calling Fiber.new does not.
  [f1, f2, f3, f4, f5, f6].each(&:transfer)
end

scheduler.catchup

puts "main 2"
$log << "main 2"

factorial_thread_or_ractor.join

puts "main 3"
$log << "main 3"
