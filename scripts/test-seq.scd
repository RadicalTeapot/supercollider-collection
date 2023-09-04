(
s.waitForBoot({
	SynthDef(\voice, {|freq = 440, cf = 400, atk = 0.01, widthMax = 1 widthMin = 0, rel = 1, atkScale = 1, relScale = 1, amp = 0.1, bus = 0|
		var sig = VarSaw.ar(freq, width: Env.perc(atk * atkScale, rel * relScale).kr(0).range(widthMin, widthMax).clip(0,1)) ! 2;
		sig = LPF.ar(sig, (cf).clip(20, 20000));
		sig = sig * Env.perc(atk, rel).kr(2) * amp;
		Out.ar(bus, sig);
	}).add;
	s.sync;

	~synth = Pbind(
		\instrument, \voice,
		#[dur, note], Prout({
			var durations = [0.25, 0.5, 1, 2] * 2;
			var weights = [2, 5, 3, 1].normalizeSum;
			var degrees = [0,3,5,7,10];
			var offsetStream = Pseq([0, -12, -7, Prand([0, -2], 1)], inf).asStream;
			loop {
				var data;
				var offset = offsetStream.next;
				weights = weights.scramble;
				data = degrees.scramble.collect({|v| [durations.wchoose(weights), v + offset] });
				rrand(1, 3).do({
					data.do({|v| v.yield});
					[0.5,Rest()].yield;
				});
				[2,Rest()].yield;
			}
		}),
	);
});
)

(
y = Pchain(
	Pbind(
		\widthMin, 0.4 - Pexprand( 0.001, 0.1, inf),
		\widthMax, Pexprand(0.5, 0.6, inf),
		\atk, 0.05,
		\rel, Pkey(\dur) * 3,
		\cf, 800 + Pkey(\freq) * 0.25,
		\amp, Pexprand(1, 3, inf) * 0.1,
	),
	~synth
).play;

~fxAndMix = {
	var synthSig, verbSig, sig;

	synthSig = In.ar(0, 2);
	synthSig = CombN.ar(synthSig, 10, 0.66, 2.5);

	verbSig = FreeVerb2.ar(synthSig[0], synthSig[1], 1, 0.8);
	verbSig = LPF.ar(HPF.ar(verbSig, 100), 5000);

	sig = SelectX.ar(0.25, [synthSig, verbSig]);

	ReplaceOut.ar(0, sig);
};

z = ~fxAndMix.play(addAction: 'addToTail');

x = Pbind(
	\instrument, \voice,
	\widthMin, 0.4 - Pexprand( 0.001, 0.1, inf),
	\widthMax, Pexprand(0.5, 0.6, inf),
	\dur, Pn(Pn(Pwrand([0.125, 0.25, Rest(0.5), Rest(1)], [3, 3, 2, 1].normalizeSum, 1), rrand(1,8)), inf),
	\amp, Pexprand(0.015, 0.1, inf),
	\cf, Pexprand(2500, 10000, inf),
	\note, Pwrand([0,3,5,7,10], [3,2,1,2,1].normalizeSum, inf)+12,
	\rel, 0.5,
	\atk, 0.05,
	\addAction, 0,
).play;
)
x.stop;
y.stop;

(
r = Routine({
	var durations = [0.125, 0.25, 0.5, 1];
	var weights = [1, 3, 5, 2].normalizeSum;
	var degrees = Scale.minorPentatonic.degrees;
	var offsetStream = Pseq([0, -12, -7, Prand([0, -2], 1)], inf).asStream;
	loop {
		var data;
		var offset = offsetStream.next;
		weights = weights.scramble;
		data = degrees.scramble.collect({|v| [durations.wchoose(weights), v + offset] });
		rrand(1, 3).do {
			data.do({|v| v.yield});
		}
	}
}).asStream;
(0..4).do{r.nextN(5).postln;}
)