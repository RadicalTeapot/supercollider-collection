(
a = {
    |freq=440, lag=0.03, amp=0.25|
    SinOsc.ar(VarLag.kr(freq, lag)) * amp;
}
)

(
b = a.play;
Routine({
    var base = 60.midicps;
    loop {
        b.set(\freq, base);
        1.yield;
        b.set(\freq, base*2);
        1.yield;
        b.set(\freq, base*4);
        1.yield;
    }
}).play;
)
b.set(\lag, 0.01);