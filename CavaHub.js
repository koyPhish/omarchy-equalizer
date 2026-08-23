.pragma library

// ── Shared cava ownership ───────────────────────────────────────────────
// The bar paints one surface per monitor, so the widget is instantiated once
// per screen. Running a cava process in each of them is pure waste: they all
// analyse the same output monitor and draw the same thing. A `.pragma library`
// is instantiated once per QML engine, and the whole shell is one engine, so
// this is the one place every copy of the widget can agree on.
//
// The first instance to ask becomes the owner and is the only one that runs
// cava; it publishes each frame here and every instance renders from it.

var _owner = null
var _subscribers = []
var _nextId = 1
var _lastLevels = []
var _lastPeak = 0
var _lastStyle = ""

function claim(candidate) {
  if (_owner === null || _owner === undefined) _owner = candidate
  return _owner === candidate
}

// Called when the owning surface goes away (monitor unplugged, plugin
// reloaded). Peers poll `hasOwner` and one of them picks the process up.
function release(candidate) {
  if (_owner === candidate) _owner = null
}

function hasOwner() {
  return _owner !== null && _owner !== undefined
}

function subscribe(onFrame, onStyle) {
  var id = _nextId++
  _subscribers.push({ id: id, onFrame: onFrame, onStyle: onStyle })
  return id
}

function unsubscribe(id) {
  for (var i = 0; i < _subscribers.length; i++) {
    if (_subscribers[i].id === id) {
      _subscribers.splice(i, 1)
      return
    }
  }
}

function publish(levels, peak) {
  _lastLevels = levels
  _lastPeak = peak
  for (var i = 0; i < _subscribers.length; i++) _subscribers[i].onFrame(levels, peak)
}

// The style picker takes effect on every monitor at once, without waiting for
// a trip through shell.json — writing that file reloads the widget, which
// would close the very panel the user is clicking in.
function publishStyle(style) {
  _lastStyle = style
  for (var i = 0; i < _subscribers.length; i++) _subscribers[i].onStyle(style)
}

function lastStyle() { return _lastStyle }

// A surface mounted after the first frame would otherwise draw nothing until
// the next one; handing it the last frame keeps a new monitor in step.
function lastLevels() { return _lastLevels }
function lastPeak() { return _lastPeak }
