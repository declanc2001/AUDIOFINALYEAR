/* Tactus — Tap Detection (Minimal) */

(
OSCdef(\tap).free;

// --- tune these ---
~tapThresh = 1.35;      // raise if too sensitive, lower if it misses taps
~tapCooldown = 0.12;    // seconds; prevents double triggers
~lastTap = 0.0;

// OPTIONAL: deadzone to reduce tiny noise (usually fine to leave)
~deadzone = 0.03;

// Change this to match the OSC address your app sends for accel.
// If you're not sure, turn OSCFunc.trace(true) on and check.
~accelAddr = '/accel';

OSCdef(\tap, { |msg, time, addr, recvPort|
    var x = msg[1].asFloat;
    var y = msg[2].asFloat;
    var z = msg[3].asFloat;

    // deadzone
    if(x.abs < ~deadzone) { x = 0 };
    if(y.abs < ~deadzone) { y = 0 };
    if(z.abs < ~deadzone) { z = 0 };

    // magnitude (overall acceleration)
    var mag = (x.squared + y.squared + z.squared).sqrt;

    // debounce using time
    var now = SystemClock.seconds;

    if((mag > ~tapThresh) and: { (now - ~lastTap) > ~tapCooldown }) {
        ~lastTap = now;
        ("TAP!  mag=" ++ mag.round(0.01) ++ "  from " ++ addr.ip).postln;
    };

}, ~accelAddr);

("Tap detection armed on " ++ ~accelAddr ++ " (port " ++ NetAddr.langPort ++ ")").postln;
) 