(
play{
    AllpassC.ar(
        SinOsc.ar([
            TChoose.kr(Impulse.kr(0.29), [40, 50, 60, 70, 80]-1),
            TChoose.kr(Impulse.kr(0.31), [40, 50, 60, 70, 80]+1)
        ]).tanh,
        0.2,
        TExpRand.ar(2e-4, 2e-1,Impulse.ar(TChoose.kr(Impulse.kr(0.37), [2, 4, 8]))).round([2e-3,4e-3]),
        2)};
)