(
NetAddr.langPort;
NetAddr.localAddr;
)

(
OSCFunc({|msg, time, addr, recvPort| msg.postln}, '/touchdesigner/slider/X');
)

(
s=Server.default;
s.waitForBoot {
    s.free;
    s.sync;

    a = {
        var sig = Pulse.ar(\freq.kr(440), \width.kr(0.5).clip(0.01, 0.99));
        sig = LPF.ar(sig, \cf.kr(20000).clip(20, 20000));
        sig = sig * Env.asr.ar(Done.none, \gate.kr(0));
        Out.ar(0, (sig!2) * \amp.kr(-24.dbamp));
    }.play;

    OSCFunc({|msg, time, addr, recvPort| s.bind { a.set(\freq, (Scale.minorPentatonic.performDegreeToKey(msg[1].linlin(0, 1, 0, 10)) + 36).midicps) } }, '/touchdesigner/slider/X');
    OSCFunc({|msg, time, addr, recvPort| s.bind { a.set(\cf, msg[1].linexp(0, 1, 100, 3000)) } }, '/touchdesigner/slider/Y');
    OSCFunc({|msg, time, addr, recvPort| s.bind { a.set(\width, msg[1].linlin(0, 1, 0.1, 0.9)) } }, '/touchdesigner/noise');
    OSCFunc({|msg, time, addr, recvPort| s.bind{ a.set(\gate, msg[1]) } }, '/touchdesigner/gate');
}
)