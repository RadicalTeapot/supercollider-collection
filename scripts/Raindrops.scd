(
s.waitForBoot {
    // Initialize
    var scales = [Scale.minorPentatonic, Scale.majorPentatonic, Scale.mixolydian, Scale.phrygian];
    var pw = 0;
    var bits = 16;
    var snowflakes = [
        (hiss: 0, bits: 32),
        (hiss: 5, bits: 8),
        (hiss: 2, bits: 9),
        (hiss: 3, bits: 12),
        (hiss: 1, bits: 12),
        (hiss: 2, bits: 12),
        (hiss: 1, bits: 12),
    ];
    var sequencers = [];
    var played_notes = [[],[]];
    var lfoSpeed = 0.1;
    var minLfoSpeed = 0.01;
    var maxHighNotes = 4;
    // Import engine
    // Generate sequences
    // UI
    // Main loop
}
)