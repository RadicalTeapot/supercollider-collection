(
~notes = (0,12..24) +.x Scale.minorPentatonic.degrees;
p = Pbind(
	// This can be made much simpler (just pick and add random octave shift after a number of repeats of scale degrees)
	// but the point was to see how a shifting subset of an array can be used as pattern source
	\note, Prout({
		var position=0, subset, wrapIndices;
		inf.do({
			wrapIndices = (position..(position + 4));
			subset = ~notes.wrapAt(wrapIndices);  // use wrapAt rather than at to wrap index if greater than array size

			rrand(4,16).do({
				yield(subset.choose - 12);
			});

			position = (0,5..(~notes.size)).choose;
		});
	}),
	\dur, Prand([1,2,4], inf) * 0.5,
	\sustain, 0.33,
	\amp, Pwrand([1, 1.25, 0.75, 0], [8, 2, 4, 3].normalizeSum, inf) * 0.5
);
)

p.play;

(
~fx = {
	var sig = In.ar(0, 2);
	sig = HPF.ar(LPF.ar(sig, 800), 50);
	sig = CombN.ar(sig, 10, 0.66, 5);
	sig = FreeVerb2.ar(sig[0], sig[1], 0.5, 0.85);
	ReplaceOut.ar(0, sig);
}.play;
)
~fx.free;