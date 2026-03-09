# Ractors

## Ractors are (actors how did I not know??)

### What's an actor?

Combines a thread with a queue and only passes immutable data

Ruby does various things to ensure side effects in one ractor can't result in a
concurrency issue in another ractor

## Sending stuff to ractors...

I prefer #<< over #send because I think of #send as the send-hack (which is technically #__send__ with
#send being originally private but I think it's public now? was this originally something within Rails?)

## Things that result in an error

## things that differ between Ractor and Thread

### #value

Ractor#value seems to block but Thread#value doesn't??
