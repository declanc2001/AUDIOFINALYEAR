
(
// Boot server (audio engine)
s.waitForBoot({

    // Simpl   e percussive synth
    SynthDef(\tactusTap, { |out=0, amp=0.6|
        var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction:2);
        var sig = (SinOsc.ar(180) * env) + (WhiteNoise.ar(0.2) * env);
        Out.ar(out, (sig * amp).dup);
    }).add;

    s.sync; // IMPORTANT: waits until SynthDef is actually on the server

    "Audio test: you should hear a tap now.".postln;
    Synth(\tactusTap); // plays once
});
)











/* Tactus — Tap triggers percussive sound */

(
/////////////////////////////////////////////////
// 1. Simple percussive synth
/////////////////////////////////////////////////

SynthDef(\tactusTap, { |out=0, amp=0.5|
    var env = EnvGen.kr(Env.perc(0.001, 0.12), doneAction:2);
    var sig;

    // short clicky thud
    sig = SinOsc.ar(180) * env;
    sig = sig + (WhiteNoise.ar(0.15) * env);

    Out.ar(out, (sig * amp).dup);
}).add;

/////////////////////////////////////////////////
// 2. Tap detection on accelerometer Z
/////////////////////////////////////////////////

OSCdef(\tapZ).free;

// Tune these
~zThresh = 10.0;       // trigger threshold
~tapCooldown = 0.0.1;   // seconds
~lastTap = 0.0;

OSCdef(\tapZ, { |msg|
    var z   = msg[1].asFloat;
    var now = SystemClock.seconds;

    if((z > ~zThresh) and: { (now - ~lastTap) > ~tapCooldown }) {
        ~lastTap = now;

        // play sound
        Synth(\tactusTap, [\amp, 0.6]);

        ("TAP -> sound  z=" ++ z.round(0.01)).postln;
    };
}, "/accelerometer/z");

"TACTUS: tap → sound active (port ".postln;
NetAddr.langPort.postln;
)
