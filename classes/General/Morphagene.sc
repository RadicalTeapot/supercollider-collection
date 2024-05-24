Gene {
    var server;
    var synth;

    * new {
        |argServer, buf, amp=0, out=0|
        ~super.new.init(argServer, buf, amp, out);
    }

    init {
        |argServer, buf, amp, out|
        server = argServer;

        SynthDef(\crossfadeLooper, {
            var buf = \buf.kr(0);
            var amp = \amp.kr(-6.dbamp);
            var out = \out.kr(0);

            var rate = \rate.kr(1, rateLag);
            var rateLag = \rateLag.kr(0);

            var crossfadeDuration = \crossfadeDuration.kr(0.05);

            var start = \start.kr(0);
            var end = \end.kr(10000);

            var bufRate = rate * BufRateScale.kr(buf);
            var frames = BufFrames.kr(buf);
            var crossfadeSamples = crossfadeDuration * BufSampleRate.kr(buf);

            var trigger = LocalIn.ar(1);
            var toggle = ToggleFF.ar(trigger);
            var invToggle = 1 - toggle;
            var toggles = [toggle, invToggle];

            var phasors = Phasor.ar(
                toggles, bufRate, 0, frames,
                (start*(rate>=0)) + (end*(rate<0))
            );
            var sigs = BufRd.ar(2, buf, phasors, interpolation: 4);

            var crossfade = VarLag.ar(toggle, crossfadeDuration);
            var sig = LinXFade2.ar(sigs[0], sigs[1], crossfade.linlin(0,1,1,-1));

            var starts = Latch.kr(start, toggles).clip(crossfadeSamples*(rate>=0), frames-(crossfadeSamples*(rate<0)));
            var ends = Latch.kr(end, toggles).clip(crossfadeSamples*(rate>=0), frames-(crossfadeSamples*(rate<0)));
            LocalOut.ar((((phasors<starts) + (phasors>ends)) * (1-toggles)).sum);

            Out.ar(out, LeakDC.ar(sig) * amp);
        }).send(server);

        server.sync;

        synth = Synth(\crossfadeLooper, [buf: buf, amp: amp, out: out]);
    }

    rate {
        |rate|
        synth.set(\rate, rate);
    }

    start {
        |start|
        synth.set(\start, start);
    }

    end {
        |end|
        synth.set(\end, end);
    }

    // TODO Other args

    free {
        synth.free;
    }
}

Morphagene {
    var server;
    var genes;

    * new {
        |argServer, buf|
        ~super.new.init(argServer, buf);
    }

    init {
        |argServer, buf|
        server = argServer;

        genes = 4.collect { Gene.new(server, buf) };
    }

    amp { |amp|
        genes.do { |gene| gene.amp(amp) };
    }

    free {
        genes.do { |gene| gene.free }
    }
}