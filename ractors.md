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

# Ractors are (actors how did I not know??)

## What's an actor?

Combines a thread with a queue and only passes immutable data

Ruby does various things to ensure side effects in one ractor can't result in a
concurrency issue in another ractor

# Sending stuff to ractors...

I prefer #<< over #send because I think of #send as the send-hack (which is technically #__send__ with
#send being originally private but I think it's public now? was this originally something within Rails?)

# Things that result in an error

## Setting a class variable from a ractor

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
