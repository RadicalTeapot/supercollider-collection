(
SynthDef.new(\looping, {
	|dur, freq|
	var env, sig;
	env = EnvGen.kr(Env(levels: [0,1,1,0], times: [0.01, dur, 0.01]), doneAction: 2);
	sig = SinOsc.ar(freq) * env * \amp.kr(1);
	sig = Pan2.ar(sig, Rand(-1, 1));
	Out.ar(0, sig);
}).add;


5.do({Routine({
	var env, freq, dur, amp;
	loop{
		dur = rrand(0.01, 0.1);
		freq = exprand(100, 3000)*2;
		amp = rrand(0.02, 0.1);
		env = Synth.new(\looping, [dur: dur, freq: freq, amp: amp]);
		dur = (rrand(0.125, 0.25) - dur).clip(0, 1);
		dur.yield;
	}
}).play});
)