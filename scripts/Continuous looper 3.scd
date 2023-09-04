(
~duration = 5;

ServerTree.removeAll;

~init = {
    ~bufs.do({|buf| buf.zero });

    ~inGroup = Group.new();
    ~recorderGroup = Group.tail();

    ~loopers = Synth(\looper, [in: ~inBus, bufNum: ~bufs, phaseOffset: [0, 0.5]], ~recorderGroup);
};

s.newBusAllocators;
~inBus = Bus.audio(s, 1);

// -----------------------------------------------
~performanceEvents = [
	{
		~bufs.do({|buf| buf.zero });
		s.bind({
            ~recorders.do({|rec| rec.set(\t_trigger, 1) });
		});
		~recorderToggle.next;
		x = ~updateSynthFreq.play;

		~mix = {
			var in = In.ar(~synthBus, 2);
			var sig = SelectX.ar(0.95, [
				in,
				In.ar(0, 2),
			]);
            // in = CombN.ar(in, 5, 0.66, 2.5);
            // in = FreeVerb2.ar(in[0], in[1], 1, 0.8);
            // in = LPF.ar(HPF.ar(in, 200), 2500);

            // sig = SelectX.ar(0.25, [
            // sig,
            // LPF.ar(FreeVerb2.ar(sig[0], sig[1], 1, 0.8), 2000)
            // ]);

            // sig = SelectX.ar(0.1, [sig, in]);
			ReplaceOut.ar(0, sig);
		}.play(addAction: 'addToTail');
		"(Re)starting";
	},
	{
		~recorderToggle.next;
		"Stop recording";
	},
	{
		x.stop;
		~mix.free;
		"Stop synth and mixer";
	},
];
~performanceEventCounter = 0;

s.waitForBoot({
    var notes;

    s.freeAll;
    Buffer.freeAll;
    s.sync;

    ~bufs = Buffer.alloc(s, ~duration * s.sampleRate, 1) ! 2;
    s.sync;

    SynthDef(\looper, {
		|bufnum, t_trigger=0, phaseOffset=0, in=0, out=0, rlev=1, plev=0, amp=1, speedFactor=2, pan=0|
        var sig, sampleRate, rate, frameCount, offset, phasor, freq, env;

        sig = In.ar(in, 1);
		RecordBuf.ar(sig, bufnum, 0, rlev.varlag(1), plev.varlag(1), trigger: t_trigger);

        sampleRate = BufSampleRate.ir(bufnum);
		rate = BufRateScale.ir(bufnum);

		frameCount = ~duration * sampleRate;
        phasor = Wrap.ar(Phasor.ar(t_trigger, speedFactor.reciprocal * rate) + phaseOffset) * frameCount;

		freq = (speedFactor-1)/(s.sampleRate * ~duration);
		env = Fold.ar(Phasor.ar(t_trigger, freq)*2);

		sig = BufRd.ar(1, bufnum, phasor, 1, 4);
		sig = Pan2.ar(sig, pan);
		Out.ar(out, sig);
	}).add;

    SynthDef(\voice, {
		|freq=440, lag=0.2, atk=0.05, rel=1, amp=0.1, out=0|
		var sig = VarSaw.ar(freq.varlag(lag, -4), 0, Env.perc(atk, rel).kr(0).linlin(0,1,0.25, 0.5)+[-0.05, 0.05]);
		sig = sig * Env.perc(atk, rel).kr(2);
		sig = LPF.ar(sig, (2500 + freq * 0.1).clip(20, 20000));
		sig = sig * amp;
		Out.ar(out, sig);
	}).add;

	s.sync;

    ServerTree.add(~init);
    ServerTree.run;
    s.sync;

    ~recorderToggle = Routine({
		var state = 1;
		loop {
            ~recorders.do({|rec| rec.set(\rlev, state, \plev, (1-state)) });
			state = 1 - state;
			1.yield;
		};
	});

	notes = Scale.minorPentatonic.degrees;
	~updateSynthFreq = Pbind(
		\instrument, \voice,
		\amp, 0.75,
		\dur, Prand([0.25, 0.5, 1, Rest(0.5)], inf),
		\lag, Pexprand(0.0001, 0.25, inf),
		\rel, Pkey(\dur) * 2,
		\note, (
			Pn(Pshuf(notes, {rrand(4, 8)}), inf)  // Shuffle the notes after 4 to 8 repeats
			+
			Pdup(Pwhite(1, 3)*notes.size, Pseq([0,-5,-12,Prand([0, -7, 7])], inf)))+12,  // Repeat the current note in seq between 1 and 3 time the note count. Since this is a multiple of the note count, it effectively changes transposition only after a whole set of shuffled note is played
		\out, ~inBus,
		\group, ~inGroup,
	);
	s.sync;
})
)

(
var result = ~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
result;
)