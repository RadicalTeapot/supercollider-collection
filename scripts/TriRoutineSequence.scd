// Simple triangle voice
(
SynthDef.new(\tri, {
	var env, filterEnv, cutoff, sig;
	env = EnvGen.kr(Env(times: [\attack.ir(0.05), \decay.ir(1)], curve: [-3, -4]), doneAction: 2);
	filterEnv = EnvGen.kr(Env(times: [\fAttack.ir(0.05), \fDecay.ir(0.25)], curve: [-3, -4]));
	cutoff = \cutoff.ir(20000) + (filterEnv * \fEnvAmp.ir(0));

	sig = LFTri.ar(\freq.kr(440)) * \amp.ir(1);
	sig = LPF.ar(sig, cutoff.clip(20, 20000));
	sig = sig * env;
	sig = Pan2.ar(sig, \pan.kr(0));

	Out.ar(\bus.ir(0), sig);
}).add;

~freqs = [36.midicps, 48.midicps, 60.midicps, 67.midicps, 72.midicps, 75.midicps, 77.midicps, 79.midicps, 83.midicps, 84.midicps];
[0.5, 1, 2].do({ |ratio|
	r = Routine({
		loop{
			var dur, pan;
			dur = [0.25, 0.5, 1].choose / ratio;  // Keep it lined to grid
			pan = rrand(-0.5, 0.5) * ratio;       // Higher pitched further away from center
			Synth.new(\tri, [
				freq: ~freqs.choose * ratio,
				cutoff: 100 * ratio,
				fEnvAmp: 300 * ratio,
				fDecay: dur/(2.0 * ratio),
				decay: dur,
				pan: pan,
				amp: 0.25 / ratio
			]);
			dur.yield;
		};
	});
	r.play;
});
)