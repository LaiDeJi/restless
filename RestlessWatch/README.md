# Restless Watch

The watch app counts reps for an armed set, records 15-second movement traces
for the phone's library, and keeps a curl-measuring lab behind its **LAB**
button. The timer arms a reps set with a recorded profile and target; the watch
counts the watch arm and reports each rep. The lab is only for tuning the curl
detector and writes one CSV per set; a Mac page (`tools/curl_live.py`) can plot
its angle and rep markers live while the watch app is attached to the Mac.

## Constraints

- Counting an armed set runs in an `HKWorkoutSession`, so it continues with the
  wrist down and the screen off. If workout access is denied, it falls back to
  the foreground. Recording a movement uses `CMSensorRecorder`, which keeps
  sampling with the wrist down and the app suspended.
- The lab does not use HealthKit and needs the app in front with the screen on.
- It counts the **watch arm only**. Alternating curls count one side.
- The production timer plays one haptic when the target is reached and when a
  recording stops. It also plays one notification haptic when a rest or timed set
  ends on the phone while the watch app is reachable; that alert does not count a
  rep or change the armed set. In the background iOS mirrors the local
  notification to the watch, so the app adds no second watch haptic. The lab
  adds none.

## Count a set for the timer

The phone arms a ready reps set with the recorded profile and target. The watch
uses `CMDeviceMotion.gravity` for the forearm elevation and the gyro rate to
reject a wrist twist, then reports each rep. Counting runs in an
`HKWorkoutSession`, so the screen can sleep and the wrist can drop. Only the
watch arm is counted, and SET DONE on the phone still works.

The first armed set asks for HealthKit workout access on the watch. Allow it;
without it counting works only while the app is in front.

A `WatchMessage.alert` from the phone plays one `.notification` haptic without
touching the token, target, reps, or phase. It is best-effort: the phone sends it
only when the watch link is reachable.

## Record a movement for the library

1. Open **Restless** on the watch and leave it on the READY screen.
2. On the phone: **SESSIONS > MOVEMENTS > + RECORD MOVEMENT** (or
   **RE-RECORD ON WATCH** on an existing movement).
3. Tap **START RECORDING**, then do the movement. The watch records a
   15-second window and shows a countdown.
4. The watch plays a haptic and sends the trace; the phone shows the derived
   profile, then you name it and save it.

## Install

1. The iOS app is installed on the phone and the watch app is embedded in it.
2. On the iPhone, open **Watch > Available Apps > Restless > Install**.
3. Open **Restless** on the watch.

If the app does not appear, open the project in Xcode, select the
`RestlessWatch` scheme and the watch destination, and run once.

## Record a set in the lab

1. Hold the watch arm down and still.
2. Tap **START SET**. Keep holding for about one second while the angle
   calibrates. The status changes to “set in progress”.
3. Do the curls. The count and angle update live.
4. Tap **STOP SET**. The log is written and queued for the phone.

Keep the screen on for the whole lab set. If the screen sleeps, the lab stops.

## Live monitor

With the watch connected to the Mac through the paired iPhone:

```bash
python3 tools/curl_live.py
```

It launches the watch app with `devicectl --console`, serves
**http://127.0.0.1:8787**, and writes `build/curl-live-*.csv`. The page shows
the filtered forearm swing, the live up/down triggers, the current low and
peak, and a marker wherever a rep is counted. **20s** shows one rep at a time;
**FULL SET** shows the whole set. The watch screen has to stay on.

The phone app does not need to be open for this path; it bypasses
WatchConnectivity.

## Get the CSV

On the iPhone: **Files > On My iPhone > Restless**, named
`curl-YYYYMMDD-HHmmss.csv`.

If the transfer did not arrive, with the watch connected to Xcode:
**Window > Devices and Simulators > [watch] > Installed Apps > Restless >
Download Container**. The file is in `AppData/Documents`.

## What the CSV contains

`time, gx/gy/gz` (gravity), `ax/ay/az` (user acceleration), `rx/ry/rz`
(rotation rate), `angle` (full gravity direction change), `swing` (forearm
elevation change — the signal the rep test uses), `reps` (the detector’s count
after that sample), and `bottom` / `peak` (the adaptive swing range at that
sample).

## Good sets to record

Keep one set per file and note the real rep count for each file:

- 10 strict full reps, normal tempo.
- 10 fast reps.
- 10 reps with a pause at the top.
- 5 partial reps (should not count).
- 10 reps with the dumbbell swinging (should count, but this shows the noise).

## How a rep is counted

Two things had to change from the first version.

**Fixed absolute gates fail.** The absolute wrist angle at the bottom of a curl
depends on the stance and the watch position, and real sets often bottom out at
70–90° instead of near zero. The detector is relative to the movement: keep the
lowest swing since the last count, call it up at `bottom + riseThreshold`, and
count when it falls `fallThreshold` from the peak.

**A wrist twist is not a curl.** The full gravity angle changes when the watch
rotates around the forearm (supination/pronation) even though the elbow never
bends. The detector therefore uses the *forearm elevation*: the angle between
gravity and the watch’s +Y axis, which runs along the forearm. A curl changes
that angle; a wrist twist leaves it nearly constant. On the recorded logs, the
twist set swings the forearm 18–36° while the real curl set swings it 107–123°.

There is a second check: during the upward phase, rotation about the watch’s
X axis (elbow flexion) must dominate rotation about the forearm’s Y axis (a
twist). This rejects a twist that happens to move the arm a little.

- `bottom` is the lowest filtered forearm swing since the last count.
- The arm is considered up when the swing rises **50°** above `bottom`.
- A rep is counted when it then falls **40°** from the peak.
- The X/Y gyro energy check must pass.
- `minimumRepDuration` 0.6 s debounce prevents a shaky bottom from double-counting.
- `calibrationDuration` 1.0 s captures the initial gravity baseline.

The count happens on the way down, so a lift without a controlled return is not
a rep. Partial reps under the 50° rise, and small oscillations at the top under
the 40° fall, are ignored.

## Tuning

The thresholds are in `RestlessWatch/Motion/RepDetector.swift`:

- `riseThreshold` 50° — how far above the low the forearm must swing.
- `fallThreshold` 40° — how far below the peak it must come back.
- `axisRatio` 1.05 — gyro X energy must beat gyro Y energy by this factor.
- `minimumRepDuration` 0.6 s — debounce between reps.
- `calibrationDuration` 1.0 s — baseline capture.

Replay a CSV offline against those thresholds before changing them. The live
page draws the current triggers as dashed lines, so it is easy to see whether a
rep crossed the rise and fell through the fall.
