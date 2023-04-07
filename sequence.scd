~notes = [0,3,5,7,11];  // Penta minor
~lengths = [4, 6, 8];   // Pattern lengths
~durations = [0.25, 0.5];  // Note durations
~root = 48;
(
~noteGen = Routine({
	var note, next, oct, length;
	inf.do({
		note = 0;
		oct = 0;
		length = ~lengths.choose;
		length.do({
			(note + (oct*12) + ~root).yield;
			next = ~notes.choose;
			if(next < note) {oct = oct + 1;} {};  // increase octave if picked note is lower than current (i.e wrap around the array)
			note = next;
		});
	});
});

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

~soundGen = Routine({
	var dur, note;
	inf.do({
		note = ~noteGen.next;
		dur = ~durations.choose;
		Synth.new(\tri, [decay: dur, freq: note.midicps, amp: 0.2]);
		dur.yield;
	});
});
)
~soundGen.play;
~soundGen.stop;