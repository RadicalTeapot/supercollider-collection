// Control rate
(
s.newBusAllocators;
~bus = Bus.control(s, 1);

{
    var trigger = LocalIn.kr(1, 1);
    var duration = Latch.kr(LFNoise1.kr(10), trigger).range(0.1, 1) * ControlRate.ir; // Note : duration shouldn't be lower than block size (64 by default)
    var phasor = Phasor.kr(trigger, 1, 0, duration*2).clip(0, duration);
    LocalOut.kr(phasor>=(duration-1));
    Out.kr(~bus, (phasor / duration));
}.play;

~bus.scope;
)

// Sample rate
(
s.newBusAllocators;
~bus = Bus.audio(s, 1);

{
    var trigger = LocalIn.ar(1, 1);
    var duration = Latch.ar(LFNoise1.ar(10), trigger).range(0.1, 1) * SampleRate.ir;
    var phasor = Phasor.ar(trigger, 1, 0, duration*2).clip(0, duration);
    LocalOut.ar(phasor>=(duration-1));
    Out.ar(~bus, (phasor / duration));
}.play;

~bus.scope;
)