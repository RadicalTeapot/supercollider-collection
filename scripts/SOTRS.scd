~useJACK.value;
(
SynthDef(\voice, {
    |freq=440, amp=0.25, out=0, cf=500|
    var detune = LFNoise2.kr(5!5).bipolar(0.17);
    var sig = VarSaw.ar(freq + detune, width: 0.25);
    sig = sig.blend(LFPulse.ar(freq * 0.5 + detune, width: 0.33), 0.66);
    sig = MoogFF.ar(sig, (cf + detune).clip(20, 20000));
    sig = Splay.ar(sig);
    Out.ar(out, sig * amp);
}).add;

Pdefn(\notes, Prout({
    var p1 = (Ppatlace([Pdup(4, Pseq([-4,-6,-8,-4], inf)), 3, 4, 6, 8], inf)).asStream;
    var p2 = (Pshuf(Scale.minor.degrees, inf)+20).asStream;
    var p3 = Pdup(20, Pseq((1,0.975..0.5), inf)).asStream;
    loop {
        var pn1 = p1.next;
        var pn2 = p2.next;
        if (exprand(0.001, 1) > p3.next) {
            Pdefn(\cf, 2000);
            pn2.yield;
        } {
            Pdefn(\cf, 500);
            pn1.yield;
        };
    }
}));
~lead = Pmono(
    \voice,
    \dur, 0.5,
    \midinote, Pdefn(\notes)+60,
    \rel, Pkey(\dur) * Pdefn(\rel),
    \cf, Pdefn(\cf),
);
)

(
~clock = TempoClock(80.0/60.0);
~lead.play(~clock);
)