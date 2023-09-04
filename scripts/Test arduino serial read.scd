~useJACK.value;

// Connect to Arduino
(
p = SerialPort(
    "COM3",           // Find out by running SerialPort.listDevices
    baudrate: 9600,
    crtscts: true
);
)

// Test serial connection
p.next;

// Create synth to send values to bitwig
a = {|values=#[0,0,0,0]| Out.ar(0, K2A.ar(values))}.play; // MAKE SURE OUTPUTS ARE NOT CONNECTED TO SYSTEM PLAYBACK IN JACK BEFORE RUNNING THIS!! (Also turn the volume down just to be safe)

(
r = Routine({
    // Expect arduino to output 4 space separated values followed by CRLF (println). i.e. 10 25 68 29CRLF16 292 0 73CRLF...
    var byte, str, values=0!4;
    var start = 10; // LF character
    var end = 13; // CR character
    var space = 32; // Space character
    var delimiter = [space, space, space, end];
    loop {
        if (p.read == start, {
            4.do({|i|
                str = "";
                while({byte = p.read; byte != delimiter[i]}, {
                    str = str ++ byte.asAscii;
                });
                values[i] = str.asInteger / 1023.0;
            });
            a.set(\values, values);
        });
    }
}).play;
)

r.stop;
a.stop;
p.close;