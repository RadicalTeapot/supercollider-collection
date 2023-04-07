s.boot;
(
// Buses and groups
s.newBusAllocators;
~synthBus = Bus.audio(s, 2);
~synthGroup = Group.new(s);
~fxGroup = Group.new(~synthGroup, 'addAfter');
~ctrlBuses = (0..3).collect({Bus.control(s)});
~ctrlGroup = Group.new(~synthGroup, 'addBefore');

// Synth defs
SynthDef(\TriLFO, {
	var sig = LFTri.kr(\freq.kr(1));
	Out.kr(\bus.kr(0), sig);
}).add;

SynthDef(\pulse, {
	var env, sig;
	env = EnvGen.kr(Env.perc(\atk.ir(0.05), \rel.ir(1)), doneAction: 2);
	sig = Pulse.ar(\freq.kr(440) + {Rand(-1, 1)}.dup(4), \pwm.kr(0.5)).sum;
	sig = LPF.ar(sig, \cf.kr(20000).clip(20, 20000));
	sig = sig * env * \amp.kr(0.1);
	sig = Pan2.ar(sig, \pan.kr(0));
	Out.ar(\bus.kr(0), sig);
}).add;

SynthDef(\reverb, {
	var input, sig;
	input = In.ar(\inputBus.kr(0), 2);
	sig = FreeVerb2.ar(input[0], input[1], \mix.kr(0.3), \size.kr(0.5), \damp.kr(0.5));
	sig = sig * \amp.kr(1);
	Out.ar(\bus.kr(0), sig);
}).add;

// Initialize synths
~lfos = [0.01, 0.5, 1, 5].collect({ |v, i| Synth.new(\TriLFO, [freq: v, bus: ~ctrlBuses[i]], ~ctrlGroup)});

~synth = Pbind(
	\instrument, \pulse,
	\dur, Prand([0.125, 0.25, 0.5], inf),
	\note, Pseq([Prand([0,3,5,7,11], 8), Prand([0, 7, 11], 3)+12], inf),
	\cf, 200 + Pkey(\freq) * 0.25 + Pfunc({ ~ctrlBuses[0].getSynchronous.linlin(-1, 1, 0, 600)}),
	\rel, Pkey(\dur) - Pexprand(0.01, 0.1),
	\pwm, Pfunc({~ctrlBuses[2].getSynchronous.linlin(-1, 1, 0.2, 0.5)}),
	\bus, ~synthBus,
	\group, ~synthGroup,
);

~bass = Pbind(
	\instrument, \pulse,
	\dur, Prand([1, 2], inf),
	\note, Prand([0, 7], inf) + Pseq([Pn(0, 8), Pn(5, 4)], inf) - 24,
	\cf, 100,
	\db, -18,
	\rel, Pkey(\dur)*2,
	\group, ~synthGroup,
);

~reverb = Synth.new(\reverb, [inputBus: ~synthBus, size: 0.85, amp: 0.8], ~fxGroup);
)

(
b = ~bass.play;
q = ~synth.play;
)

b.stop;
q.stop;
