MIDIClient.init;
MIDIClient.list;
MIDIClient.sources;

// Connect to a specific input
// MIDIIn.connect(0, MIDIClient.sources[0].uid);
MIDIIn.connectAll;  // Connect to all inputs

(
a = MIDIFunc.start({"Start".postln;});
b = MIDIFunc.stop({"Stop".postln;});
c = MIDIFunc.noteOn({|vel, note, channel, src| ("Note " ++ note ++" on channel " ++ (channel+1)).postln;}, 60, 0);
d = MIDIFunc.noteOn({|vel, note, channel, src| ("Any note (" ++ note ++ ") on channel " ++ (channel+1)).postln;}, chan: 0);
e = MIDIFunc.noteOn({|vel, note, channel, src| ("Any note (" ++ note ++ ") on any channel (" ++ (channel + 1) ++ ")").postln;})
)

// Cleanup (Ctrl + . would also work)
[a,b,c,d,e].do{|v| v.free};

// Debug on
MIDIFunc.trace(true);
// Debug off
MIDIFunc.trace(false);