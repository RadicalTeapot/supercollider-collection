~useJACK.value;

(
~performanceEventCounter = 0;

// -----------------------------------------------
// Functions
~midiFuncs = (
    \start: {
        "MIDI Start".postln;
        ~nextRountine = Routine({
            loop {
                // Set and tweak patterns here (this will advance each time note 60 on channel 16 is received (i.e. heartbeat))
                // use it to create the piece evolution

                "Using first pattern set".postln;
                Pdefn(\durDef, Pwrand([1,2,4,Rest(2)], [1, 3, 3, 2].normalizeSum, inf));
                Pdefn(\noteDef, Plazy({~generateNotePattern.(notes: #[0,3,7], minTransRepeat: nil, globalTranspose: 0)}));  // Function call needs to be wrapped as Plazy arg (the event) would be passed as the argument otherwise
                Pdefn(\ampDef, Pexprand(0.5, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax') * -9.dbamp);
                1.yield;

                "Using second pattern set".postln;
                Pdefn(\noteDef, Plazy({~generateNotePattern.(notes: #[0,3,7])}));
                Pdefn(\ampDef, Pexprand(0.5, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax') * -6.dbamp);
                1.yield;

                "Using thrid pattern set".postln;
                Pdefn(\noteDef, Plazy({~generateNotePattern.()}));
                Pdefn(\ampDef, Pexprand(0.5, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax') * - 3.dbamp);
                1.yield;

                "Using fourth pattern set".postln;
                Pdefn(\durDef, Pwrand([0.5,1,2,Rest(2)], [2, 3, 3, 1].normalizeSum, inf));
                1.yield;

                "Using fifth pattern set".postln;
                Pdefn(\durDef, Pwrand([0.5,1,2,Rest(2)], [4, 1, 1, 2].normalizeSum, inf));
                1.yield;

                "Using sixth pattern set".postln;
                Pdefn(\ampDef, Pexprand(0.5, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax'));
                1.yield;

                "Using seventh pattern set".postln;
                Pdefn(\durDef, Pwrand([0.25,0.5,2,Rest(1)], [2, 4, 1, 2].normalizeSum, inf));
                1.yield;

                "Using eigth pattern set".postln;
                Pdefn(\noteDef, Plazy({~generateNotePattern.(notes: #[0,3,7])}));
                Pdefn(\ampDef, Pexprand(0.5, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax') * -6.dbamp);
                Pdefn(\durDef, Pwrand([0.5,1,2,Rest(2)], [2, 3, 3, 1].normalizeSum, inf));
                1.yield;

                "Using last pattern set".postln;
                Pdefn(\noteDef, Plazy({~generateNotePattern.(globalTranspose: 24)}));
                Pdefn(\durDef, Pwrand([0.25,0.5,1], [4, 2, 1].normalizeSum, inf));
                Pdefn(\ampDef, Pexprand(0.66, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax'));
                1.yield;
                1.yield;
            }
        });
        ~nextRountine.next;
        ~startPerformance.(useSimpleMix: true);
    },
    \stop: {
        "MIDI Stop".postln;
        ~stopPerformance.();
    },
    \next: {
        "MIDI Next".postln;
        ~nextRountine.next;
    },
);

~connectMidi = {
    if (MIDIClient.initialized == false) {MIDIClient.init;} {};
    // catch exception thrown when already connected
    try {MIDIIn.connectAll;} {"Already connected, won't reconnect;".postln;};

    MIDIdef.freeAll;
    MIDIdef.start(\start, ~midiFuncs[\start]);
    MIDIdef.stop(\stop, ~midiFuncs[\stop]);
    MIDIdef.noteOn(\next, ~midiFuncs[\next], 60, 15);
};

~startPerformance = {|useSimpleMix = false|
    ~recordingBuffer.zero;

    a = ~lead.play;
    // a = ~midiLead.play;

    if (useSimpleMix)
    {b = ~simpleMix.play(~mixGroup);}
    {b = ~fxAndMix.play(~mixGroup);};

    "Perfomance started".postln;
};

~stopPerformance = {
    a.stop;
    b.free;

    "Perfomance stopped".postln;
};

~performanceEvents = [
    // Fill with array of functions to call to move the performance along
    {~startPerformance.(useSimpleMix: true);},
    {a.stop;},
    ~stopPerformance,
];

~generateNotePattern = {
    |transposePattern, notes = #[0,3,5,7,10], minRepeat = 4, maxRepeat = 8, minTransRepeat = 1, maxTransRepeat = 3, globalTranspose = 12|
    var shuffledRepeats, transpose;
    shuffledRepeats = Pn(Pshuf(notes, {rrand(minRepeat, maxRepeat)}));

    if (transposePattern.isNil) {transposePattern=Pseq([-12,-5,0,Prand([0, -7, 7])], inf);} {};
    if (minTransRepeat.isNil or: {maxTransRepeat.isNil} )
    {transpose = 0}
    {transpose = Pdup(
        Pwhite(minTransRepeat, maxTransRepeat) * notes.size, // Multiply by notes.size to keep it aligned with note shuffle pattern
        transposePattern,
    )};

    shuffledRepeats + transpose + globalTranspose;
};

// -----------------------------------------------
// Server init / clean
ServerTree.removeAll;

~runOnServerRestart = { s.bind({
    ~synthGroup = Group.head();
    ~bufferGroup = Group.tail();
    ~mixGroup = Group.tail();

    // Recorder
    ~recorder = Synth(\recorder, [inputBus: ~synthBus, bufnum: ~recodingBuffer, gate: 1, plev: -3.dbamp, amp: 2], ~bufferGroup);

    // Loopers
    ~loopers = [
        [panRange: 0.2, amp: 3, baseRate: 0.25],
        [panRange: 0.5, amp: 2, baseRate: 0.5],
        [panRange: 1, amp: 1, baseRate: 2, timescale: 1],
        [panRange: 1, amp: 0.5, baseRate: 4, timescale: 2],
    ].collect({ |spec|
        Synth(\looper, [\bufnum: ~recordingBuffer, \bus: ~looperBus] ++ spec, ~synthGroup);
    });

    ~lfos = [0.01, 0.033, 0.1, 1].collect({ |v, i|
        var synth = Synth(\triLFO, [freq:  v, bus: i]);
        (\synth: synth, \bus: i);
    });

    ~fxAndMix = {
        var synthSig, looperSig, sig, verb;

        synthSig = Pan2.ar(SoundIn.ar(0), 0);// In.ar(~synthBus, 2);
        synthSig = MoogFF.ar(synthSig, In.kr(~lfos[0][\bus]).range(200, 2000).clip(20, 20000));
        synthSig = synthSig * (0.1 + In.kr(~lfos[1][\bus]).unipolar(0.1).clip(0, 0.1));
        synthSig = CombN.ar(synthSig, 10, 0.66, In.kr(~lfos[1][\bus]).range(5, 10));

        looperSig = In.ar(~looperBus, 2);
        looperSig = MoogFF.ar(looperSig, In.kr(~lfos[1][\bus]).range(600, 200).clip(20, 20000));
        looperSig = HPF.ar(looperSig, In.kr(~lfos[0][\bus]).range(50, 80).clip(20, 20000));
        looperSig = looperSig * (0.75 + In.kr(~lfos[2][\bus]).unipolar(0.25).clip(0, 0.25));

        sig = SelectX.ar(In.kr(~lfos[1][\bus]).range(0.4, 0.4), [synthSig, looperSig]);
        verb = FreeVerb2.ar(sig[0], sig[1], 1, 0.9);
        sig = SelectX.ar(In.kr(~lfos[0][\bus]).range(0.7, 0.4), [sig, verb]);

        Out.ar(0, sig);
    };

    ~simpleMix = {
        Out.ar(0, In.ar(~synthBus, 2));
        Out.ar(2, In.ar(~looperBus, 2));
    };

    ~connectMidi.value;

    // MIDI out
    // if (MIDIClient.initialized == false) {MIDIClient.init;} {MIDIClient.list;};
    // ~midiDevice = MIDIOut.newByName("2- Studio 68c MIDI Out", "2- Studio 68c MIDI Out");
}); };

// -----------------------------------------------
// Busses
s.newBusAllocators;
~synthBus = Bus.audio(s, 2);
~looperBus = Bus.audio(s, 2);

s.waitForBoot({
    var notes;
    // Cleanup
    s.freeAll;
    Buffer.freeAll;

    s.sync;

    // -----------------------------------------------
    s.newBufferAllocators;
    ~recordingBuffer = Buffer.alloc(s, s.sampleRate * 23.7, 2);

    s.sync;

    // -----------------------------------------------
    // Define synths
    SynthDef(\recorder, {
        var sig;
        sig = In.ar(\inputBus.ir(0), 2);//Pan2.ar(SoundIn.ar(0), 0);
        RecordBuf.ar(sig, \bufnum.ir(0), recLevel: \rlev.kr(1), preLevel: \plev.kr(0.5), run: \gate.kr(0));
    }).add;

    SynthDef(\player, {
        var sig;
        sig = PlayBuf.ar(2, \bufnum.ir(0), loop: 1);
        Out.ar(\bus.ir(0), sig);
    }).add;

    SynthDef(\looper,{
        // main arguments
        arg bufnum,bus=0,baseRate=1.0,amp=1.0,timescale=0.2,panRange=1,ampIncreaseDurationStart=5,ampIncreaseDurationEnd=2;
        // variables to store UGens later
        var volume;
        var switch=0,snd,snd1,snd2,pos,pos1,pos2,posStart,posEnd,index;
        // store the number of frames and the duraiton
        var frames=BufFrames.kr(bufnum);
        var duration=BufDur.kr(bufnum);
        var sampleRate = BufSampleRate.kr(bufnum);
        // LFO for the start point <-- tinker
        var lfoStart=SinOsc.kr(timescale/Rand(30,60),Rand(hi:2*pi)).range(1024,frames-10240);
        // LFO for the window lenth <-- tinker
        var lfoWindow=SinOsc.kr(timescale/Rand(60,120),Rand(hi:2*pi)).range(4096,frames/2);
        // LFO for the rate (right now its not an LFO)
        var lfoRate=baseRate;//*Select.kr(SinOsc.kr(1/Rand(10,30)).range(0,4.9),[1,0.25,0.5,1,2]);
        // LFO for switching between forward and reverse <-- tinker
        var lfoForward=Demand.kr(Impulse.kr(timescale/Rand(5,15)),0,Drand([0,1],inf));
        // LFO for the volume <-- tinker
        var lfoAmp=SinOsc.kr(timescale/Rand(10,30),Rand(hi:2*pi)).range(0.05,0.5);
        // LFO for the panning <-- tinker
        var lfoPan=SinOsc.kr(timescale/Rand(10,30),Rand(hi:2*pi)).range(-1,1) * panRange;

        // calculate the final rate
        var rate=Lag.kr(lfoRate*(2*lfoForward-1),1)*BufRateScale.kr(bufnum);

        // modulate the start/stop
        posStart = lfoStart;
        posEnd = Clip.kr(posStart + lfoWindow,0,frames-1024);

        // LocalIn collects the a trigger whenever the playhead leaves the window
        switch=ToggleFF.kr(LocalIn.kr(1));

        // playhead 1 has a play position and buffer reader
        pos1=Phasor.ar(trig:1-switch,rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
        snd1=BufRd.ar(2,bufnum,pos1,1.0,4);

        // playhead 2 has a play position and buffer reader
        pos2=Phasor.ar(trig:switch,  rate:rate,end:frames,resetPos:((lfoForward>0)*posStart)+((lfoForward<1)*posEnd));
        snd2=BufRd.ar(2,bufnum,pos2,1.0,4);

        // current position changes according to the swtich
        pos=Select.ar(switch,[pos1,pos2]);

        // send out a trigger anytime the position is outside the window
        LocalOut.kr(
            Changed.kr(Stepper.kr(Impulse.kr(20),max:1000000000,
                step:(pos>posEnd)+(pos<posStart)
            ))
        );

        // crossfade bewteen the two sounds over 50 milliseconds
        snd=SelectX.ar(Lag.kr(switch,0.05),[snd1,snd2]);

        // apply the volume lfo
        volume = amp*lfoAmp*EnvGen.ar(Env.new([0,1],[Rand(1,10)],4));
        volume = volume * lfoWindow.linlin(ampIncreaseDurationEnd * sampleRate, ampIncreaseDurationStart * sampleRate, 1.5, 1);

        // do the panning
        snd=Balance2.ar(snd[0],snd[1],lfoPan);

        // final output
        Out.ar(bus,snd*volume/5);
    }).add;

    SynthDef(\triLFO, {
        var sig = LFTri.kr(\freq.ir(1));
        Out.kr(\bus.kr(0), sig);
    }).add;

    s.sync;

    // -----------------------------------------------
    ServerTree.add(~runOnServerRestart);
    ServerTree.run;

    s.sync;
    // -----------------------------------------------
    Pdefn(\durDef, Pwrand([1,2,4,Rest(2)], [1, 3, 3, 2].normalizeSum, inf));
    Pdefn(\noteDef, Plazy({~generateNotePattern.();}));
    Pdefn(\ampDef, Pexprand(0.5, 0.75, inf) * Pkey(\freq).linlin(700, 1500, 1, 0.1, 'minmax'));
    notes = Scale.minorPentatonic.degrees;
    ~lead = Pbind(
        \dur, Pdefn(\durDef),
        \sustain, 0.5,
        \note, Pdefn(\noteDef),
        \pan, Pmeanrand(-0.7, 0.7, inf),
        \amp, Pdefn(\ampDef),
        \group, ~synthGroup,
        \out, ~synthBus,
    );

    ~midiLead = Pbind(
        \type, \midi,
        \midiout, ~midiDevice,
        \midicmd, \noteOn,
        \chan, 0,
        \sustain, 0.5 * Pkey(\dur),
        \midinote, Pdefn(\noteDef) + 36,
    ) <> ~lead;
});
)
~midiDevice.allNotesOff(0);

// Perform
(
~performanceEvents[~performanceEventCounter].value;
~performanceEventCounter = (~performanceEventCounter + 1) % ~performanceEvents.size;
)

Pdefn(\durDef, Pwrand([1,2,4,Rest(2)] * 1, [1, 3, 3, 2].normalizeSum, inf));
Pdefn(\noteDef, Plazy({~generateNotePattern.(globalTranspose: -12);}));
~midiDevice.control(0, 20, 100);

~recordingBuffer.plot;