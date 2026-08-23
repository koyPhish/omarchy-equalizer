import QtQuick
import Quickshell.Io

// Owns one cava process and turns its ascii frames into level arrays.
// The config is fed through a process substitution so nothing has to be
// written to disk and a settings change simply rebuilds the command.
Item {
  id: root

  property int bars: 12
  property int framerate: 30
  property int noiseReduction: 77
  property string channels: "mono"
  property string source: "auto"
  property bool running: true

  // cava's autosens keeps amplifying while the room is quiet, so an idle
  // stream still floats around 0..4. Anything above that is real audio.
  readonly property int silenceFloor: 6

  property bool everRead: false
  property bool failed: false
  property bool _ready: false

  signal frame(var levels, int peak)

  readonly property var command: {
    var lines = [
      "[general]",
      "framerate = " + framerate,
      "bars = " + bars,
      "autosens = 1",
      "[input]",
      "method = pipewire",
      "source = " + source,
      "[output]",
      "method = raw",
      "raw_target = /dev/stdout",
      "data_format = ascii",
      "ascii_max_range = 100",
      "bar_delimiter = 59",
      "frame_delimiter = 10",
      "channels = " + channels,
      "mono_option = average",
      "[smoothing]",
      "noise_reduction = " + (noiseReduction / 100)
    ]
    var quoted = []
    for (var i = 0; i < lines.length; i++) quoted.push("'" + lines[i].replace(/'/g, "'\\''") + "'")
    return ["bash", "-c", "exec cava -p <(printf '%s\\n' " + quoted.join(" ") + ")"]
  }

  // The process is driven imperatively rather than bound to `running`:
  // assigning to Process.running to force a restart would clobber the
  // binding and leave the wrong state stuck.
  function sync() {
    if (root.running && !proc.running) proc.running = true
    else if (!root.running && proc.running) proc.running = false
  }

  function hardRestart() {
    root.everRead = false
    root.failed = false
    proc.running = false
    if (root.running) {
      restartTimer.restart()
      probeTimer.restart()
    }
  }

  function consume(data) {
    if (!data) return
    var parts = data.split(";")
    var levels = []
    var peak = 0
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].length === 0) continue
      var value = parseInt(parts[i], 10)
      if (isNaN(value)) value = 0
      if (value > peak) peak = value
      levels.push(value)
    }
    if (levels.length === 0) return

    root.everRead = true
    root.failed = false
    root.frame(levels, peak)
  }

  Component.onCompleted: { root._ready = true; sync() }
  onRunningChanged: if (root._ready) sync()
  onCommandChanged: if (root._ready) hardRestart()

  Process {
    id: proc
    command: root.command
    stdout: SplitParser {
      onRead: function(data) { root.consume(data) }
    }
    onExited: function(exitCode, exitStatus) {
      if (root.running) retryTimer.restart()
    }
  }

  Timer { id: restartTimer; interval: 150; onTriggered: root.sync() }
  Timer { id: retryTimer; interval: 5000; onTriggered: root.sync() }

  // If no frame has arrived after a few seconds, cava is missing or the
  // PipeWire monitor is unavailable. Say so instead of showing nothing.
  Timer {
    id: probeTimer
    interval: 3000
    running: root.running
    onTriggered: root.failed = !root.everRead
  }
}
