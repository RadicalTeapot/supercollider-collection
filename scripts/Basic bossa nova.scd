(
~chordDegrees = Pseq([
    Pn([0, 9, 14, 16, 19], 16),   // C A D E G -> C6/9
    Pn([-3, 9, 13, 17, 19], 16),  // A A Db F G -> A7#5 (either A altered scale (I chord) or F Locrian Major (III chord))
    Pn([2, 9, 12, 17, 19], 16),   // D A C F G -> Dm11
    Pn([-5, 11, 15, 17, 21], 16), // G B D# F A -> G9#5 (either G Locarian Major (I chord) or C Melodic Minor (V chord))
], inf);

~chordPattern = Pseq([     // x - x - - x - x - x - x - x - -
    Pseq([1, Rest(1)], 2),
    Pseq([Rest(1), 1], 5),
    Rest(1), Rest(1)
], inf);

~notesDegrees = Pseq([
    Pseq([Pn(0, 4), Pser([Pwrand([7, -5], [0.25, 0.75]), Pn(0, 3), Pn(0, 4)], 5)], 1),     // C - - C G - - - C - - - G - - -
    Pseq([Pn(-3, 4), Pser([Pwrand([4, -8], [0.25, 0.75]), Pn(-3, 3), Pn(-3, 4)], 5)], 1),  // A - - A E - - - A - - - E - - -
    Pseq([Pn(2, 4), Pser([Pwrand([9, -3], [0.25, 0.75]), Pn(2, 3), Pn(2, 4)], 5)], 1),     // D - - D A - - - D - - - A - - -
    Pseq([Pn(-5, 4), Pser([Pwrand([2, -10], [0.25, 0.75]), Pn(-5, 3), Pn(-5, 4)], 5)], 1), // G - - G D - - - G - - - D - - -
], inf);

~notesPattern = Pseq([     // x - - x x - - - x - - - x - (x) -
    1, Rest(1), Rest(1), 1,
    Pseq([1, Rest(1), Rest(1), Rest(1)], 2),
    1, Rest(1), Prand([Rest(1), 1]), Rest(1),
], inf);
)

(
~chords = Pbind(
    \dur, ~chordPattern,
    \degree, ~chordDegrees - 12,
    \amp, 0.05,
    \sustain, Pseq([Pn(0.25, 13), 1.5, 0.25, 0.25], inf),
);
~notes = Pbind(
    \dur, ~notesPattern,
    \degree, ~notesDegrees,
    \amp, 0.15,
    \sustain, Pseq([2, Pn(1, 2), 0.5, Pseq([3, Pn(1, 3)], 3)], inf),
);
)

(
~clock = TempoClock(260/60);
~clock.beats_(-0.1);
~chords.play(~clock, quant: 1);
~notes.play(~clock, quant: 1);
)