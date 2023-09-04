// Connect to Arduino
(
p = SerialPort(
    "COM3",           // Find out by running SerialPort.listDevices
    baudrate: 9600,
    xonxoff: true     // Works better than crtscts when using USB
);
)

(
~notes = [12,24] +.x Scale.minorPentatonic.degrees.scramble;
Pbind(
    \type, \rest,
    \dur, Pwhite(1, 10) * Pdup(16, Pseq([1, 0.5, 0.75, 1, 1], inf)),
    \gateLength, (Pkey(\dur) * Pwhite(0.125, 0.5) * 1000).asInteger, // In ms
    \note, Prand(~notes, inf)
).collect({
    |ev|
    var char;

    ("New note: " ++ ev.note ++ " dur: " ++ ev.gateLength).postln;

    p.putAll([13,10]); // CRLF
    p.putAll("" ++ ev.note ++ " " ++ (ev.gateLength) ++ " "); // Not sure if the final space is needed

    ev
}).play;
)

p.close;
p.isOpen;