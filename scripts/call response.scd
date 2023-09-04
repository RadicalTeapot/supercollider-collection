~useAudioInterface.();

(
~leftPhraseLength = 4;
~leftCounter = 0;
~left = Pbind(
    \instrument, \defaultPluck,
    \pan, -0.33,
    \dur, Pwrand([0.25, 0.5, 1], [0.5, 0.25, 0.25], inf),
    \midinote, Pn(Pshuf(Scale.dorian.degrees, {rrand(1, 3)})) + 60,
    \atk, 0.01,
    \cutoff, 2000,
    \fEnvAmp, 1000,
    \rq, 0.75,
    \type, Pfunc({if (~leftCounter < 0) {\rest} {\note} }),
).collect({|ev| ~leftCounter = ~leftCounter + ev.dur; if (~leftCounter > (~leftPhraseLength - 0.001)) {~leftCounter = ~rightPhraseLength * -1; ~leftPhraseLength = rrand(3, 6); }; ev });

~rightPhraseLength = 4;
~rightCounter = 0;
~right = Pbind(
    \instrument, \defaultPluck,
    \pan, 0.33,
    \dur, Prand([0.5, 1, 2], inf),
    \midinote, Pn(Pshuf(Scale.minorPentatonic.degrees, {rrand(1, 3)})) + 48,
    \rel, 2,
    \subAmp, 0.2,
    \detune, 1,
    \spread, 0.2,
    \cutoff, 400,
    \fAtk, 0.25,
    \fEnvAmp, 100,
    \rq, 0.75,
    \type, Pfunc({if (~rightCounter < 0) {\rest} {\note} }),
).collect({|ev| ~rightCounter = ~rightCounter + ev.dur; if (~rightCounter > (~rightPhraseLength - 0.001)) {~rightCounter = ~leftPhraseLength * -1; ~rightPhraseLength = rrand(4, 8); }; ev });

~stream = Ptpar([0, ~left, ~leftPhraseLength, ~right]).play;
)