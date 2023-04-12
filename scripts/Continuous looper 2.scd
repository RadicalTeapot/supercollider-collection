/**
 * Looping recoder without clicks (once recording is stopped)
 * Main idea is to crossfade between to read positions in the buffer based on speed factor
 * See notes in relevant places for more details
**/
(
~duration = 5;

// -----------------------------------------------
ServerTree.removeAll;
~init = {
	~buf.zero;
	s.bind({
		~synthGroup = Group.head();
		~recGroup = Group.tail();
		~playerGroup = Group.tail();

		~recorder = Synth(\recorder, [in: ~synthBus, bufnum: ~buf], ~recGroup);
		~players = [2,4,8].collect({|v| Synth(\player, [bufnum: ~buf, speedFactor: v, amp:(10-v).reciprocal, pan:rrand(-0.5, 0.5)], ~playerGroup)});
	});
};

// -----------------------------------------------
~performanceEvents = [
	{
		~buf.zero;
		// It's important to trigger both at the same time to make sure playheads are in sync
		// A better way to do so would be to output a single phasor to a control bus for the record head
		// and read from it in recorder and player, then methods would always be synced
		s.bind({
			~recorder.set(\t_trigger, 1);
			~playerGroup.set(\t_trigger, 1);
		});
		~recorderToggle.next;
		x = ~updateSynthFreq.play;

		~mix = {
			var in = In.ar(~synthBus, 2);
			var sig = SelectX.ar(0.95, [
				in,
				In.ar(0, 2),
			]);
			in = CombN.ar(in, 5, 0.66, 2.5);
			in = FreeVerb2.ar(in[0], in[1], 1, 0.8);
			in = LPF.ar(HPF.ar(in, 200), 2500);

			sig = SelectX.ar(0.25, [
				sig,
				LPF.ar(FreeVerb2.ar(sig[0], sig[1], 1, 0.8), 2000)
			]);

			sig = SelectX.ar(0.1, [sig, in]);
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
		~playerGroup.set(\t_trigger, 1);
		"Stop synth and mixer";
	},
];
~performanceEventCounter = 0;

// -----------------------------------------------
s.newBusAllocators;
~synthBus = Bus.audio(s, 2);

// -----------------------------------------------
s.waitForBoot({
	var notes;

	s.freeAll;
	Buffer.freeAll;
	s.sync;

	// -----------------------------------------------
	// Duration multipled by 1.5 as it's the max needed when min speed factor is 2 (see player synth)
	~buf = Buffer.alloc(s, s.sampleRate * ~duration * 1.5, 2);
	s.sync;

	// -----------------------------------------------
	SynthDef(\recorder, {
		|bufnum, in=0, rlev=1, plev=0, t_trigger=0|
		var sig = In.ar(in, 2);
		RecordBuf.ar(sig, bufnum, 0, rlev.varlag(1), plev.varlag(1), trigger: t_trigger);
	}).add;

	SynthDef(\player, {
		// speedFactor is how many times slower to read the buffer* (e.g. 2 is twice as slow)
		// If synced, for a given speedFactor x > 1 the record and play head will cross (x-1) times over a duration of (x*bufferLength) (e.g for a speedFactor of 4 and a buffer length of 1 the heads will cross 3 times over 4 seconds (when play head is at 1/4, 1/2, 3/4 and 1 times the buffer length))
		|bufnum, out=0, amp=1, speedFactor=2, t_trigger=0, pan=0|
		var sampleRate = BufSampleRate.ir(bufnum);
		var rate = BufRateScale.ir(bufnum);

		var frameCount = ~duration * sampleRate;
		var offset = (~duration / speedFactor) * sampleRate; // Offset the second play-head by position of play head at first cross time
		var phasors = Phasor.ar(t_trigger, speedFactor.reciprocal * rate, end: frameCount) + [0, offset];

		var freq = (speedFactor-1)/(s.sampleRate * ~duration); // Calculate the freq of the crossfade (i.e. number of times heads cross during a full play read)
		var env = Fold.ar(Phasor.ar(t_trigger, freq)*2);       // Triggered triangle env

		var sig = BufRd.ar(2, bufnum, phasors, 1, 4);
		sig = SelectX.ar(env, sig) * amp;
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

	// -----------------------------------------------
	ServerTree.add(~init);
	ServerTree.run;
	s.sync;

	// -----------------------------------------------
	~recorderToggle = Routine({
		var state = 1;
		loop {
			~recorder.set(\rlev, state, \plev, (1-state));
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
		\out, ~synthBus,
		\group, ~synthGroup,
	);
	s.sync;
});
)

// -----------------------------------------------
// Perform
(
var result = ~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
result;
)