import QtQuick

// Draws one cava frame. Every style shares the same band geometry — the
// bands march along one axis and the level grows along the other — so the
// only thing a style changes is what gets painted inside a band.
//
// `vertical` transposes the whole thing for a bar docked to a screen side:
// bands stack downwards and levels grow sideways.
Item {
  id: root

  property var levels: []
  property int bandCount: 12
  property int thickness: 3
  property int gap: 2
  property real extent: 16
  property bool vertical: false
  property color tint: "white"
  property string style: "bars"
  property int blockCount: 5
  property int blockGap: 2
  property int animationMs: 60

  readonly property int span: bandCount * thickness + Math.max(0, bandCount - 1) * gap
  readonly property real crossAvail: vertical ? width : height

  implicitWidth: vertical ? extent : span
  implicitHeight: vertical ? span : extent

  function levelAt(index) {
    if (!levels || index >= levels.length) return 0
    return Math.max(0, Math.min(1, levels[index] / 100))
  }

  Repeater {
    model: root.bandCount

    delegate: Item {
      id: band
      required property int index

      readonly property real level: root.levelAt(index)
      readonly property real reach: Math.max(2, level * root.crossAvail)

      x: root.vertical ? 0 : index * (root.thickness + root.gap)
      y: root.vertical ? index * (root.thickness + root.gap) : 0
      width: root.vertical ? root.width : root.thickness
      height: root.vertical ? root.thickness : root.height

      // ── bars · grounded · dots ───────────────────────────────────────
      Rectangle {
        visible: root.style !== "blocks"
        radius: root.thickness / 2
        color: root.tint
        opacity: 0.45 + 0.55 * band.level

        readonly property real mark: root.style === "dots" ? root.thickness : band.reach

        width: root.vertical ? mark : root.thickness
        height: root.vertical ? root.thickness : mark

        // Centered for `bars`, pinned to the floor for `grounded`, and
        // floated at the level's height for `dots`. The floor is the far
        // edge: the bottom of a horizontal bar, the outer side of a
        // vertical one.
        x: {
          if (!root.vertical) return 0
          if (root.style === "bars") return (band.width - width) / 2
          if (root.style === "dots") return band.level * (band.width - width)
          return 0
        }
        y: {
          if (root.vertical) return 0
          if (root.style === "bars") return (band.height - height) / 2
          if (root.style === "dots") return (band.height - height) - band.level * (band.height - height)
          return band.height - height
        }

        Behavior on width { enabled: root.vertical && root.style !== "dots"; NumberAnimation { duration: root.animationMs; easing.type: Easing.OutQuad } }
        Behavior on height { enabled: !root.vertical && root.style !== "dots"; NumberAnimation { duration: root.animationMs; easing.type: Easing.OutQuad } }
        Behavior on x { enabled: root.vertical && root.style === "dots"; NumberAnimation { duration: root.animationMs; easing.type: Easing.OutQuad } }
        Behavior on y { enabled: !root.vertical && root.style === "dots"; NumberAnimation { duration: root.animationMs; easing.type: Easing.OutQuad } }
      }

      // ── blocks ───────────────────────────────────────────────────────
      // A segmented LED column: each block lights once the level clears its
      // share of the range, so the readout is quantised rather than smooth.
      Repeater {
        model: root.style === "blocks" ? root.blockCount : 0

        delegate: Rectangle {
          required property int index

          readonly property real segment: Math.max(
            1, (root.crossAvail - (root.blockCount - 1) * root.blockGap) / root.blockCount)
          readonly property bool lit: band.level >= (index + 1) / root.blockCount
          readonly property real offset: index * (segment + root.blockGap)

          width: root.vertical ? segment : root.thickness
          height: root.vertical ? root.thickness : segment
          x: root.vertical ? offset : 0
          y: root.vertical ? 0 : band.height - segment - offset

          radius: Math.min(root.thickness, segment) / 3
          color: root.tint
          opacity: lit ? 0.95 : 0.12

          Behavior on opacity { NumberAnimation { duration: root.animationMs; easing.type: Easing.OutQuad } }
        }
      }
    }
  }
}
