// Pulse train
(
~freqs = [36.midicps, 48.midicps, 60.midicps, 67.midicps, 72.midicps, 75.midicps, 77.midicps, 79.midicps, 83.midicps, 84.midicps];
SynthDef.new(\voice, {
	var sig, triggers, freq, dur, env, pan;

	triggers = LFPulse.kr(Rand(\pulseFreqMin.kr(0.02), \pulseFreqMax.kr(0.2)));

	dur = TRand.kr(\minDur.kr(1), \maxDur.kr(4), triggers);
	env = EnvGen.kr(Env([0, 1, 0], [0.05, dur], [-3, -3]), triggers);

	freq = Demand.kr(triggers, 0, Drand(~freqs, inf));
	sig = SinOsc.ar(freq);

	sig = sig * env * \amp.kr(0.1);
	pan = TRand.kr(\minPan.kr(-1), \maxPan.kr(1), triggers);
	sig = Pan2.ar(sig, pan);

	Out.ar(\bus.kr(0), sig);
}).add;
)

x = (0..9).collect({ Synth.new(\voice, [minDur: 2, maxDur: 5]) });
x.do({ |synth| synth.free; });