(
s.newBusAllocators;
// ~debugBus = Bus.control(s, 4);
~synthBus = Bus.audio(s, 2);
~synthGroup = Group.new();
~tailGroup = Group.tail();

Buffer.freeAll;
~buf = Buffer.alloc(s, 60.0 * s.sampleRate, 2);

SynthDef(\voice, {
    var sig = SinOsc.ar(\freq.kr(440)).dup;
    var env = Env.perc(releaseTime: \rel.kr(1)).kr(2);
    Out.ar(\out.kr(0), sig * env * \amp.kr(0.1))
}).add;

SynthDef(\brokenTape, {
    |buf, cleanGate=1, degradeTrigFreq=0.1, decimateTrigFreq=0.1, lpTrigFreq=0.1, hpTrigFreq=0.1, probability=0.1|
    var in, bufFrames, sig, pSig, phasor,
    glitchTrig, glitchRate, glitchGate=0, glitchPos, glitchPhasor, glitchSig,
    decimatorTrig, decimatorRate, decimatorGate=0, decimatorSig,
    lpTrig, lpCutoff, lpGate=0, lpSig,
    hpTrig, hpCutoff, hpGate=0, hpSig;

    bufFrames = BufFrames.ir(buf);
    in = SoundIn.ar(\in.kr([0,1]), 2);

    phasor = Phasor.ar(0, 1, 0, bufFrames);
    pSig = BufRd.ar(2, buf, phasor, 1, 4);

    sig = in.blend(pSig, (1-cleanGate).varlag(0.1));
    BufWr.ar(sig, buf, phasor);

    glitchTrig = CoinGate.kr(probability * (1-cleanGate) * (1-glitchGate), Dust.kr(degradeTrigFreq));
    glitchGate = EnvGen.kr(Env([0,1,0], [0,TRand.kr(0.1, 2, glitchTrig)], \hold), glitchTrig);
    glitchPos = TRand.kr(0, bufFrames, glitchTrig);
    glitchRate = TWChoose.kr(glitchTrig, [-2, -1, -0.5, 0.5, 1, 2], [1, 5, 1, 2, 20, 2].normalizeSum);
    glitchPhasor = Phasor.ar(glitchTrig, glitchRate, 0, bufFrames, glitchPos);
    glitchSig = BufRd.ar(2, buf, glitchPhasor, 1, 4);
    sig = sig.blend(glitchSig, glitchGate.varlag(0.02));

    decimatorTrig = CoinGate.kr(probability * (1-cleanGate) * (1-decimatorGate), Dust.kr(decimateTrigFreq));
    decimatorGate = EnvGen.kr(Env([0,1,0], [0,TRand.kr(0.5, 5, decimatorTrig)], \hold), decimatorTrig);
    decimatorRate = TRand.kr(s.sampleRate * 0.01, s.sampleRate * 0.2, decimatorTrig);
    decimatorSig = Decimator.ar(sig, decimatorRate);
    sig = sig.blend(decimatorSig, decimatorGate.varlag(0.1));

    lpTrig = CoinGate.kr(probability * (1-cleanGate) * (1-lpGate), Dust.kr(lpTrigFreq));
    lpGate = EnvGen.kr(Env([0,1,0], [0,TRand.kr(0.5, 5, lpTrig)], \hold), lpTrig);
    lpCutoff = 20000 - TExpRand.kr(1, 15000, lpTrig);
    lpSig = LPF.ar(sig, lpCutoff.clip(20, 20000));
    sig = sig.blend(lpSig, lpGate.varlag(0.1));

    hpTrig = CoinGate.kr(probability * (1-cleanGate) * (1-hpGate), Dust.kr(hpTrigFreq));
    hpGate = EnvGen.kr(Env([0,1,0], [0,TRand.kr(0.5, 5, hpTrig)], \hold), hpTrig);
    hpCutoff = TExpRand.kr(20, 5000, hpTrig);
    hpSig = HPF.ar(sig, hpCutoff.clip(20, 20000));
    sig = sig.blend(hpSig, hpGate.varlag(0.1));

    // TODO Play with pan too
    // TODO Add tape noise (before decimator, maybe even before glitch)

    BufWr.ar(sig, buf, phasor);

    Out.ar(\out.kr(0), sig);
}).add;

Pdefn(\dur, Prand([0.25, 0.5, 1, Prand([Rest(0.25), Rest(0.5), Rest(1)], 1)], inf));
Pdefn(\degree, Pn(Pn(Pdup({[1, 2, 4].wchoose([0.5, 0.3, 0.2])}, Pshuf(Scale.minorPentatonic.degrees, 1)), {rrand(1, 4)})));

~lead = Pbind(
    \instrument, \voice,
    \dur, Pdefn(\dur) * 0.5,
    \rel, Pkey(\dur) * 2,
    \degree, Pdefn(\degree),
    \out, ~synthBus,
    \group, ~synthGroup,
);
)

(
// ~lead.play;
~tape = Synth(\brokenTape, [\buf: ~buf, \in: [2,3], \probability: 0.1], ~tailGroup);
)
~tape.set(\cleanGate, 0);
~tape.set(\probability, 1);