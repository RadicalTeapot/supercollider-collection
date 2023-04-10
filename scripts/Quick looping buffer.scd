/**
 * Quick demo of implementation of a looper without clicks.
 * Based on a video by Eli Fieldsteel here (https://www.youtube.com/live/3NgCFsmGQgM?feature=share&t=1516)
 *
 * See comment in \recoder SynthDef for more explanation of the technique
*/

(
~setupInOuts = {
	// Set input and output devices to JACK and allocate 4 outputs bus by default
	var serverOptions = Server.default.options;
	serverOptions.inDevice_("ASIO : JackRouter");
	serverOptions.outDevice_("ASIO : JackRouter");
	serverOptions.numOutputBusChannels_(4);
	Server.default.reboot;
};
// ~setupInOuts.();

// -----------------------------------------------
ServerTree.removeAll;

~runOnServerRestart = {
	s.bind({
		~synthGroup = Group.new();
		~recGroup = Group.new(~synthGroup, 'addAfter');
		~playGroup = Group.new(~recGroup, 'addAfter');

		~recorder = Synth(\recorder, [in: ~synthBus, bufnum: ~buf], ~recGroup);
		~player = Synth(\player, [bufnum: ~buf], ~playGroup);
	});
};

// -----------------------------------------------
~performanceEvents = [
	{
		~recorderToggle.next(1);
		x = Synth(\voice, [out: ~synthBus], ~synthGroup);
		r = ~updateSynthFreq.(x).play;
		"(Re)starting";
	},
	{
		~recorderToggle.next;
		"Stop recording";
	},
	{
		r.stop;
		x.free;
		"Killed synth and routine";
	}
];
~performanceEventCounter = 0;

// -----------------------------------------------
s.newBusAllocators;
~synthBus = Bus.audio(s, 1);

// -----------------------------------------------
s.waitForBoot({
	// Cleanup
	s.freeAll;
	Buffer.freeAll;
	s.sync;

	// -----------------------------------------------
	// Create and load buffers
	~buf = Buffer.alloc(s, s.sampleRate * 3, 1);
	s.sync;

	// -----------------------------------------------
	// Add synthdefs
	SynthDef(\recorder, {
		|lagSpeed = 0.3|
		var sig = In.ar(\in.ir(0), 1);
		RecordBuf.ar(sig, \bufnum.ir(0), \offset.kr(0),
			\rlev.kr(1).varlag(lagSpeed), // Trick to avoid clicks is here, lag the level changes to create a crossfading tail between the
			\plev.kr(0).varlag(lagSpeed)  // current values and the start ones
		);
	}).add;

	SynthDef(\player, {
		var sig = PlayBuf.ar(1, \bufnum.ir(0), loop: 1);
		sig = sig * \amp.kr(0.1);
		Out.ar(\out.ir(0), sig!2);
	}).add;

	SynthDef(\voice, {
		var sig = LFTri.ar(\freq.kr(440).varlag(\lag.kr(0.2), -4));
		sig = sig * \amp.kr(0.1);
		Out.ar(\out.ir(0), sig);
	}).add;

	s.sync;

	// -----------------------------------------------
	// Run start command
	ServerTree.add(~runOnServerRestart);
	ServerTree.run;

	s.sync;

	// -----------------------------------------------
	// Create routines / Pbinds / functions
	~recorderToggle = Routine({
		|state = 1|
		loop {
			~recorder.set(\rlev, state, \plev, (1-state));
			state = 1 - state;
			1.yield;
		};
	});

	~updateSynthFreq = {|synth|
		Routine({
			var freqs = Scale.minorPentatonic.degrees.collect({|v| (v + 60).midicps;}).scramble;
			var freqStream = Pseq(freqs, inf).asStream;
			loop {
				synth.set(\freq, freqStream.next);
				0.25.yield;
			};
		});
	};
});
)

// -----------------------------------------------
// Perform
(
var result = ~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
result;
)