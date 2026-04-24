<!-- TOC -->
* [Ractors are (actors how did I not know??)](#ractors-are-actors-how-did-i-not-know)
  * [What's an actor?](#whats-an-actor)
* [Sending stuff to ractors...](#sending-stuff-to-ractors)
* [Things that result in an error](#things-that-result-in-an-error)
  * [Setting a class variable from a ractor](#setting-a-class-variable-from-a-ractor)
    * [workarounds for the above?](#workarounds-for-the-above)
  * [creating a new method on an existing class with `def`](#creating-a-new-method-on-an-existing-class-with-def)
  * [creating a new method on an existing class with `define_method`](#creating-a-new-method-on-an-existing-class-with-define_method)
    * [if it contains references to outer variables](#if-it-contains-references-to-outer-variables)
    * [If it does not contain outer variables and is called within the ractor](#if-it-does-not-contain-outer-variables-and-is-called-within-the-ractor)
    * [If it does not contain outer variables and is called outside the ractor](#if-it-does-not-contain-outer-variables-and-is-called-outside-the-ractor)
* [When will objects passed to a ractor be silently duped?](#when-will-objects-passed-to-a-ractor-be-silently-duped)
* [things that differ between Ractor and Thread](#things-that-differ-between-ractor-and-thread)
* [Unsure if there's a public interface to whatever deep-dups unshareable objects passed to ractors, but it is not #make_shareable](#unsure-if-theres-a-public-interface-to-whatever-deep-dups-unshareable-objects-passed-to-ractors-but-it-is-not-make_shareable)
  * [#value](#value)
* [Benchmarks](#benchmarks)
<!-- TOC -->

# Ractors are actors! (how did I not know??)

## What's an actor?

Combines a thread with a queue and only passes immutable data

Ruby does various things to ensure side effects in one ractor can't result in a
concurrency issue in another ractor

# Sending stuff to ractors...

## #send versus #<<

I suppose prefer #<< over #send because I think of #send as the send-hack (which is technically #__send__ with
#send being originally private but I think it's public now? was this originally something within Rails?)

However, an oddity is if you're moving an object to a Ractor, then it would be `some_ractor.<<(some_object, move: true)`
which seems kind of awkward.

# Things that result in an error

## Setting a class instance variable from a ractor

```ruby
Ractor.new do
  Object.class_eval { @foo = :bar }
end.join
```

results in:

```
'block (2 levels) in <main>': can not set instance variables of classes/modules by non-main Ractors (Ractor::IsolationError)
```

Q: What if the class is created in the ractor? Is it allowed then?
A: Same error.

Q: What if the class created in the ractor is anonymous?
A: Same error.

Q: What if I "move" the class to the ractor? Can I change its instance variables then?
A: No, same error.

Q: What if I "pass" the class to the ractor's constructor? Can I change its instance variables then?
A: No, same error.

Q: What if I freeze and object, pass it to the ractor, and then unfreeze it?
A: You can't unfreeze an object (at least not through any public interface)

### workarounds for the above?

Maybe use ractor-local variables instead of class variables for things like caches?

## creating a new method on an existing class with `def`

It works!

## creating a new method on an existing class with `define_method`

### if it contains references to outer variables

Does not work

### If it does not contain outer variables and is called within the ractor

It works!

### If it does not contain outer variables and is called outside the ractor

It does not work! Even when the proc does not reference any state at all! Hmmm... that's a surprise!

# When will objects passed to a ractor be silently duped?

This results in deep-duping the object:

```ruby
o = Object.new
puts "object_id outside ractor: #{o.object_id}"

Ractor.new do
  puts "object_id in ractor: #{receive.object_id}"
end.send(o).join
```

This is because `Ractor.shareable?(o)` is `false` because it is not deeply shareable.

TODO: what is shareable?

nil, true, false, symbols, integers/floats/etc
classes are shareable (I guess because of all that instance-variable-mutation-forbidden-ness stuff?)
objects that are frozen and all of their instance variables contain shareable values

# things that differ between Ractor and Thread

# Unsure if there's a public interface to whatever deep-dups unshareable objects passed to ractors, but it is not #make_shareable

```
irb(main):004> o = Object.new
=> #<Object:0x00007fc9cbc6f9c0>
irb(main):005> o.singleton_class.class_eval { attr_accessor :foo }
=> [:foo, :foo=]
irb(main):006> o.foo = Object.new
=> #<Object:0x00007fc9cbb6da68>
irb(main):007> o2 = Ractor.make_shareable(o)
=> #<Object:0x00007fc9cbc6f9c0 @foo=#<Object:0x00007fc9cbb6da68>>
irb(main):008> o.object_id
=> 100144
irb(main):009> o2.object_id
=> 100144
irb(main):010> Ractor.shareable?(o)
=> true
irb(main):011> o.frozen?
=> true
irb(main):012> Object.methods.grep /dup/
=> [:dup]
irb(main):013>
```


## #value

Ractor#value seems to block but Thread#value doesn't??

# Benchmarks

# Other random interesting tidbits

## Is the random number upper bound just Math::E or related to it??

## Initializing a ractor and a thread aren't quite the same

Have to pass a block to Ractor.new but just need Thread#initialize to take a block.

This has some implications for inheriting from Ractor versus inheriting from Thread.

```ruby
class MyThread < Thread
  def initialize(...)
    super { do_it }
  end
end
```

works, but

```ruby
class MyRactor < Ractor
  def initialize(...)
    super { do_it }
  end
end
```

does not because one has to attack .new instead of #initialize for Ractor.


## Additional note... the value of self in a ractor block is the ractor class?? not the created instance??


## wwwhwhhhaaaat?? Why does eval break but not define_method in this other case??

## another issue...

╭┨~/gitlocal/ruby/promises┠┨main┠─────────────────────────────────────────────────────────────────────────────────────────────────────────┨2026-04-06 09:13:04
╰./example_scripts/doubler                                                                                                                                   
/home/miles/gitlocal/ruby/promises/src/ractorized_object.rb:13: warning: Ractor API is experimental and may change in future versions of Ruby.
20
ractor is #<Ractor:#1 running> 16
#<Thread:0x00007f3219a3ce90 run> terminated with exception (report_on_exception is true):
./example_scripts/doubler:10:in 'Doubler#set': can not access instance variables of shareable objects from non-main Ractors (Ractor::IsolationError)
from /home/miles/gitlocal/ruby/promises/src/ractorized_object.rb:26:in 'block (2 levels) in RactorizedObject.new'
from /home/miles/gitlocal/ruby/promises/src/ractorized_object.rb:16:in 'Kernel#loop'
from /home/miles/gitlocal/ruby/promises/src/ractorized_object.rb:16:in 'block in RactorizedObject.new'
^C/home/miles/gitlocal/ruby/promises/src/ractorized_object/promise.rb:14:in 'Ractor::Port#receive': Interrupt
from /home/miles/gitlocal/ruby/promises/src/ractorized_object/promise.rb:14:in 'RactorizedObject::Promise#value'
from ./example_scripts/doubler:30:in '<main>'

even if an object is shareable, the main ractor can't access its data? Hmm...

# wrapping a method outside super doesn't work??

# breaks coverage in simplecov?

# strange bug in this branch:

╭┨~/gitlocal/ractor-shack/ractorize┠┨bring-back-ractorized-object┠────────────────────────────────────────────────────────────────────────┨2026-04-09 16:31:03
╰example_scripts/doubler                                                                                                                                     
/home/miles/gitlocal/ractor-shack/ractorize/src/ractorized_object.rb:10: warning: Ractor API is experimental and may change in future versions of Ruby.
example_scripts/doubler:25:in 'Ractor::MovedObject#method_missing': can not send any methods to a moved object (Ractor::MovedError)
from example_scripts/doubler:25:in '<main>'
╔╣~/gitlocal/ractor-shack/ractorize╠╣bring-back-ractorized-object╠════════════════════════════════════════════════════════════════════════╣2026-04-09 16:31:04
╚       

So this seems to mean that we cannot go with the RactorizedObject approach where we prepend a module to
an existing object.

That is because we need to move the object to the ractor. But if we move the object to the ractor, 
then calling code doing stuff like doubler.set(10) will fail because of this error and not get a chance
to send the message along to the ractor that will then invoke the overriden (original) method.

Maybe proxy approach is best, then?

# When I send messages to a ractor, will they arrive in order?

# Why is #method_missing in the moved error message?

./scripts/passing-objects/moving:19:in 'Ractor::MovedObject#method_missing': can not send any methods to a moved object (Ractor::MovedError)
from ./scripts/passing-objects/moving:19:in '<main>'

# the "non-proxy problem"

any approach to provide methods that delegate to a Ractor that ultimately call real methods
on the same object seems to not work...

The approach of moving "self" to the ractor and back doesn't seem to work since the
reference to the object that is moved through the return port works, old references don't work.

Not sure why? Flags in the Ruby "VALUE" reference?

Also, if anything asyncronously accesses the object while it's moved to the other ractor, it fails. Internally,
one catch MoveError and wait. But outside in the calling code this isn't an ergonomic solution.

Not moving the object is tricky because we can't access instance variables from the Ractor that didn't
create the object. This means we can't have a @__ractor__ to refrence it from the object and we can't make
a "ractor = Ractor.current; target.define_method(:__ractor__) { ractor }" because this proc is considered
not accessible from the outside ractor.

# start off by explaining what ractors are
## where relevant: CRuby due to its GIL
# explain what problems they solve and how
# examples:
## cpu-bound work
## race condition without semaphores
