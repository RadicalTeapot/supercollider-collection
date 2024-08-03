(
s.waitForBoot {
    var pointCount, pointBus, getTriggerSynth;
    s.newBusAllocators;
    s.sync;

    pointCount = 64;
    pointBus = Bus.control(s, pointCount);

    // This one is as optimized as possible
    SynthDef(\points, {
        var offset = Array.interpolation(pointCount);
        var rate = \freq.kr(1) * ControlDur.ir;
        var sig = Phasor.kr(rate: rate) + offset % 1.0;
        Out.kr(\out.ir(0), sig - rate);
    }).add;

    getTriggerSynth = {|bus, pointCount, idx, path='/trigger', name=\trigger|
        SynthDef(name, {
            var points = bus.kr(pointCount);

            /*// Worst case
            var trigger = Changed.kr(PulseCount.kr(points - \offset.kr(0)));
            var prob = TRand.kr(trig: trigger) <= \probability.kr(1);
            SendReply.kr(trigger*prob, path, trigger*prob);
            */

            /*// Best case
            var trigger = Changed.kr(PulseCount.kr(points - \offset.kr(0)));
            var prob = TRand.kr(trig: trigger) <= \probability.kr(1);
            (trigger * prob).do {|trig, i|  SendReply.kr(trig, path, [i, idx]) }
            */

            // Equaly best case (maybe more readable
            points.do { |point, i|
                var trigger = Changed.kr(PulseCount.kr(point - \offset.kr(0)));
                var prob = TRand.kr(trig: trigger) <= \probability.kr(1);
                SendReply.kr(trigger*prob, path, [i, idx]);
            }
        }).add;
        s.sync;
        Synth.tail(s, name);
    };
    s.sync;

    Synth.head(s, \points, [out: pointBus]);
    getTriggerSynth.(pointBus, pointCount, 1, '/trigger', \trigA);
    getTriggerSynth.(pointBus, pointCount, 2, '/trigger', \trigB).set(\offset, 0.5);
    OSCFunc({ |msg| msg[3..].postln  }, '/trigger');
};
)