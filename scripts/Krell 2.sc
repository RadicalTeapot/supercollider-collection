(
~freqs = [36.midicps, 48.midicps, 55.midicps, 60.midicps, 63.midicps, 65.midicps, 67.midicps, 71.midicps, 72.midicps,] * 2;

SynthDef(\voice, {
	var amp, trig, freq, env, sig, pan, dur;
	trig = LFPulse.kr(Rand(\minPulseFreq.kr(0.1), \maxPulseFreq.kr(0.5)));  // Trigger
	amp = TExpRand.kr(0.01, 0.1, trig); // Amplitude (randomized on each trigger)
	pan = TRand.kr(-1, 1, trig);        // Pan (randomized on each trigger)
	freq = Demand.kr(trig, 0, Drand(~freqs, inf));  // Pitch (randomized on each trigger)
	dur = TRand.kr(1, 4, trig);         // Env release duration (randomized on each trigger)
	env = EnvGen.kr(Env([0,1,0], [0.05, dur], [-3,-3]), trig);  // AD env (triggered on each trigger)
	sig = SinOsc.ar(freq);  // Sine output
	sig = sig * env * amp;  // Level control
	sig = Pan2.ar(sig, pan);  // Pan control and out
	Out.ar(\bus.kr(0), sig);
}).add;
)

x = (0..9).collect({ Synth.new(\voice) });
x.do({|item| item.free});

s.plotTree;