// Chord to emotions from here https://www.tabletopcomposer.com/post/chord-relationships-and-emotion
(
s = Server.default;
s.waitForBoot {
    s.free;
    s.sync;

    SynthDef(\strings, {
        var sig = Saw.ar(\freq.kr(440) * LFNoise2.ar(0.2!5).range(-0.25, 0.25).midiratio *
            SinOsc.ar(\tremoloFreq.ar(4)).unipolar(\tremoloDepth.kr(0.5)).midiratio);
        sig = sig * SinOsc.ar(\vibratoFreq.kr(4)).range(1 - \viratoDepth.kr(0.2),1).clip(0, 1);
        sig = LPF.ar(sig, \cf.kr(20000).clip(20, 20000));
        sig = sig * Env.asr(\atk.kr(2), 1, \rel.kr(5)).ar(Done.none, \gate.kr(1), timeScale: \dur.kr(1));
        sig = Splay.ar(sig, \spread.kr(1), center: \pan.kr(0));
        sig = sig * \amp.kr(-6.dbamp);
        sig = NHHall.ar(sig, 10, 0.2);
        DetectSilence.ar(sig, doneAction: Done.freeSelf);
        Out.ar(\out.ir(0), sig);
    }).add;
    s.sync;
};
)

(
~a = [-12, -5, 0, 4, 7, 12].collect{|note|
    var root = 60;
    var freq = (root + note).midicps;
    Synth(\strings, [freq: freq, cf: freq * 0.8, amp: -12.dbamp, tremoloDepth: 0.5]);
};
)

( // Heavenly
(([-12, -5, 0, 3, 7, 12] + 9).wrap(-12, 12).sort).do { |note, i|
    var root = 60;
    var freq = (root + note).midicps;
    ~a[i].set(\freq, freq, \cf, freq * 0.8);
};
)

( // Fantastical
(([-12, -5, 0, 4, 7, 12] + 8).wrap(-12, 12).sort).do { |note, i|
    var root = 60;
    var freq = (root + note).midicps;
    ~a[i].set(\freq, freq, \cf, freq * 0.8);
};
)

( // Wonder
(([-12, -5, 0, 3, 7, 12] + 7).wrap(-12, 12).sort).do { |note, i|
    var root = 60;
    var freq = (root + note).midicps;
    ~a[i].set(\freq, freq, \cf, freq * 0.8);
};
)

(
([-12, -5, 0, 4, 7, 12]).do { |note, i|
    var root = 60;
    var freq = (root + note).midicps;
    ~a[i].set(\freq, freq, \cf, freq * 0.8);
};
)

~a.do { |synth| synth.set(\gate, 0) }
