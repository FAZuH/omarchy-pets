pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Sprite.js" as Sprite

Panel {
  id: root
  moduleName: "raiden-meixelysia.omarchy-pets"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string petsDir: {
    var raw = String(root.setting("petsDir", "~/.codex/pets"))
    return raw === "~" || raw.indexOf("~/") === 0 ? home + raw.slice(1) : raw
  }
  readonly property string petId: String(root.setting("petId", ""))
  readonly property bool smoothScaling: root.setting("smooth", true) === true
  readonly property bool animate: root.setting("animate", true) === true
  readonly property bool randomBehavior: root.setting("randomBehavior", true) === true
  readonly property bool pinned: root.setting("pinned", false) === true
  readonly property int pinnedX: root.setting("pinnedX", -1)
  readonly property int pinnedY: root.setting("pinnedY", -1)
  readonly property real pinnedScale: {
    var s = Number(root.setting("pinnedScale", 1))
    return s > 0 ? s : 1
  }
  readonly property int walkRadius: Math.max(0, Number(root.setting("walkRadius", 0)) || 0)
  readonly property int walkMin: Math.min(walkRadius, Math.max(0, Number(root.setting("walkMin", 0)) || 0))
  readonly property bool walk: root.setting("walk", false) === true
  readonly property int randomness: Math.max(0, Math.min(100, Math.round(Number(root.setting("randomness", 50)))))
  property int dragDx: 0
  property int dragDy: 0
  readonly property bool dragging: dragDx !== 0 || dragDy !== 0

  // Stroll: offsets from the pinned spot, the target, and rest time between strolls.
  property bool walkMoving: false
  property real walkDx: 0
  property real walkDy: 0
  property real walkTx: 0
  property real walkTy: 0
  property real walkDwell: 0
  readonly property int previewCount: 3
  property bool showAll: false
  readonly property var currentPet: {
    var pets = library.pets
    for (var i = 0; i < pets.length; i++) if (pets[i].name === petId) return pets[i]
    return pets.length > 0 ? pets[0] : null
  }
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: Style.hoverFillFor(barForeground, Color.accent)
  readonly property color selectedFill: Style.selectedFillFor(barForeground, Color.accent)

  // Stage position inside the card, screen coordinates.
  readonly property real cardInnerWidth: panel.contentWidth - Border.left(panel.borderSpec) - Border.right(panel.borderSpec) - panel.padding * 2
  readonly property int stageScreenX: Math.round(panel.cardOrigin.x + Border.left(panel.borderSpec) + panel.padding + (cardInnerWidth - stage.width) / 2)
  readonly property int stageScreenY: Math.round(panel.cardOrigin.y + Border.top(panel.borderSpec) + panel.padding)

  // Pinned position: saved or card spot, plus drag, clamped.
  readonly property int restX: pinnedX >= 0 ? pinnedX : stageScreenX
  readonly property int restY: pinnedY >= 0 ? pinnedY : stageScreenY
  readonly property int petX: Math.max(0, Math.min(restX + dragDx + Math.round(walkDx), pinnedWindow.width - stage.width))
  readonly property int petY: Math.max(0, Math.min(restY + dragDy + Math.round(walkDy), pinnedWindow.height - stage.height))

  onOpenedChanged: {
    if (opened) library.rescan()
    else showAll = false
  }
  onPinnedChanged: {
    if (pinned) root.controller.hide()
    else {
      walkMoving = false
      walkDx = 0
      walkDy = 0
    }
  }
  onWalkChanged: if (!walk) {
    walkMoving = false
    walkDx = 0
    walkDy = 0
  }

  function open() {
    if (pinned) saveSetting("pinned", false)
    root.controller.show()
  }

  function toggle() {
    if (pinned || !opened) open()
    else close()
  }

  function dragPet(dx, dy) {
    if (!pinned) return
    dragDx = petX + dx - restX
    dragDy = petY + dy - restY
  }

  function dropPet() {
    if (!pinned) return
    var x = petX
    var y = petY
    dragDx = 0
    dragDy = 0
    walkMoving = false
    walkDx = 0
    walkDy = 0
    walkDwell = Sprite.walkDwellMs(Math.random()) * Sprite.randomnessFactor(root.randomness)
    saveSetting("pinnedX", x)
    saveSetting("pinnedY", y)
  }

  function currentSettings() {
    return {
      petId: String(root.setting("petId", "")),
      petsDir: String(root.setting("petsDir", "~/.codex/pets")),
      smooth: root.setting("smooth", true) === true,
      pinned: root.setting("pinned", false) === true,
      pinnedX: root.setting("pinnedX", -1),
      pinnedY: root.setting("pinnedY", -1),
      pinnedScale: root.pinnedScale,
      randomBehavior: root.setting("randomBehavior", true) === true,
      animate: root.setting("animate", true) === true,
      walk: root.setting("walk", false) === true,
      walkRadius: root.setting("walkRadius", 0),
      walkMin: root.setting("walkMin", 0),
      randomness: root.setting("randomness", 50)
    }
  }

  function saveSetting(key, value) {
    var shellApi = bar && bar.shell ? bar.shell : null
    if (shellApi && shellApi.pluginRegistry && typeof shellApi.pluginRegistry.setBarWidget === "function") {
      var error = shellApi.pluginRegistry.setBarWidget(moduleName, key, value, {})
      if (!error) {
        console.log("omarchy-pets: " + key + " = " + JSON.stringify(value))
        return
      }
      console.warn("omarchy-pets: saving " + key + " via registry failed: " + error)
    }
    // Bar widgets only get the scoped shell facade, which has no
    // pluginRegistry. updateEntryInline is the supported write path here;
    // it replaces the layout entry, so send the full merged settings.
    if (shellApi && typeof shellApi.updateEntryInline === "function") {
      var merged = currentSettings()
      merged[key] = value
      if (shellApi.updateEntryInline(moduleName, merged)) {
        console.log("omarchy-pets: " + key + " = " + JSON.stringify(value))
        return
      }
    }
    console.warn("omarchy-pets: cannot save " + key + ": no writable shell API")
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  PetLibrary {
    id: library
    active: root.hostWidget !== null
    petsDir: root.petsDir
  }

  // Reparented between the card and the pinned window.
  Item {
    id: stage
    parent: root.pinned ? pinnedSlot : panelSlot
    x: root.pinned ? root.petX : 0
    y: root.pinned ? root.petY : 0
    width: root.pinned ? Math.round(192 * root.pinnedScale) : 192
    height: root.pinned ? Math.round(208 * root.pinnedScale) : 208

    PetSprite {
      id: sprite
      anchors.fill: parent
      sheetUrl: root.currentPet ? root.currentPet.sheetUrl : ""
      smoothScaling: root.smoothScaling
      cellScale: root.pinned ? root.pinnedScale : 1
      running: (root.opened || root.pinned) && root.animate && root.currentPet !== null
      randomBehavior: root.randomBehavior
      randomness: root.randomness
      walking: root.walk && root.walkMoving && root.walkRadius > 0 && !sprite.hovering && !root.dragging
      onDragged: function(dx, dy) { root.dragPet(dx, dy) }
      onDropped: root.dropPet()
    }

    Timer {
      id: walker
      interval: 33
      repeat: true
      running: root.pinned && root.animate && root.walk && root.walkRadius > 0 && root.currentPet !== null

      onRunningChanged: {
        if (!running) return
        walkMoving = false
        walkDwell = Sprite.walkDwellMs(Math.random()) * Sprite.randomnessFactor(root.randomness)
      }

      onTriggered: {
        if (sprite.hovering || root.dragging) return
        if (pinnedWindow.width < stage.width || pinnedWindow.height < stage.height) return
        if (!walkMoving) {
          walkDwell -= interval
          if (walkDwell > 0) return
          var point = Sprite.randomRingPoint(Math.random(), Math.random(), root.walkMin, root.walkRadius)
          walkTx = Math.max(0, Math.min(restX + point.x, pinnedWindow.width - stage.width)) - restX
          walkTy = Math.max(0, Math.min(restY + point.y, pinnedWindow.height - stage.height)) - restY
          walkMoving = true
        }
        var oldX = walkDx
        var pos = Sprite.walkToward(walkDx, walkDy, walkTx, walkTy, Sprite.WALK_SPEED * interval / 1000)
        walkDx = pos.x
        walkDy = pos.y
        if (pos.x > oldX + 0.01) sprite.facing = 1
        else if (pos.x < oldX - 0.01) sprite.facing = -1
        if (pos.arrived) {
          walkMoving = false
          walkDwell = Sprite.walkDwellMs(Math.random()) * Sprite.randomnessFactor(root.randomness)
        }
      }
    }

    PanelActionButton {
      visible: !root.pinned
      anchors.top: parent.top
      anchors.right: parent.right
      iconText: "\u{f0403}"
      tooltipText: "Pin to the desktop"
      foreground: root.barForeground
      fontFamily: root.fontFamily
      onClicked: root.saveSetting("pinned", true)
    }
  }

  PanelWindow {
    id: pinnedWindow
    visible: root.pinned && root.currentPet !== null
    screen: panel.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-pets"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
      left: true
      top: true
      right: true
      bottom: true
    }
    mask: Region {
      x: stage.x
      y: stage.y
      width: stage.width
      height: stage.height
    }

    Item {
      id: pinnedSlot
      anchors.fill: parent
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: parent.width
          spacing: Style.space(10)

        Item {
          id: panelSlot
          visible: root.currentPet !== null
          anchors.horizontalCenter: parent.horizontalCenter
          width: stage.width
          height: stage.height
        }

        Text {
          width: parent.width
          text: root.currentPet ? root.currentPet.displayName : "Pets"
          color: root.barForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          visible: library.pets.length === 0
          width: parent.width
          text: "No pets in " + root.petsDir + "\nDownload one from codex-pets.net and unzip it into " + root.petsDir + "/<id>/"
          color: Qt.darker(root.barForeground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WrapAnywhere
        }

        Button {
          visible: root.showAll
          width: parent.width
          leftAlign: true
          iconText: "\uf053"
          text: "Back"
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: root.showAll = false
        }

        ListView {
          visible: library.pets.length > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(320))
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.showAll ? library.pets : library.pets.slice(0, root.previewCount)

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: PetRow {
            required property var modelData
            width: ListView.view.width
            pet: modelData
            current: root.currentPet !== null && root.currentPet.name === modelData.name
            foreground: root.barForeground
            fontFamily: root.fontFamily
            smoothScaling: root.smoothScaling
            fill: root.hoverFill
            currentFill: root.selectedFill
            onClicked: root.saveSetting("petId", modelData.name)
          }
        }

        Button {
          visible: !root.showAll && library.pets.length > root.previewCount
          width: parent.width
          leftAlign: true
          iconText: "\uf054"
          text: "View all " + library.pets.length + " pets"
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: root.showAll = true
        }

        Toggle {
          width: parent.width
          label: "Smooth scaling"
          description: "Turn off for pixel-art pets"
          checked: root.smoothScaling
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: root.saveSetting("smooth", !root.smoothScaling)
        }

        Toggle {
          width: parent.width
          label: "Random behaviour"
          description: "A move of its own at random intervals, paced by Randomness below"
          checked: root.randomBehavior
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: root.saveSetting("randomBehavior", !root.randomBehavior)
        }

        Toggle {
          width: parent.width
          label: "Animate"
          description: "Off shows one still frame and runs no timer"
          checked: root.animate
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: root.saveSetting("animate", !root.animate)
        }

        Toggle {
          width: parent.width
          label: "Walk around"
          description: "The pinned pet strolls around the spot you dropped it"
          checked: root.walk
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: {
            if (!root.walk && root.walkRadius === 0) root.saveSetting("walkRadius", 150)
            root.saveSetting("walk", !root.walk)
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          Text {
            width: parent.width
            text: "Pinned size — " + Math.round(root.pinnedScale * 100) + "%"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Scale of the pet while pinned to the desktop"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            value: root.pinnedScale
            minimum: 0.5
            maximum: 3
            step: 0.25
            onReleased: function(v) { root.saveSetting("pinnedScale", Math.round(v * 100) / 100) }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap
          enabled: root.walk
          opacity: root.walk ? 1 : 0.4

          Text {
            width: parent.width
            text: root.walkRadius > 0 ? "Walk radius — " + root.walkRadius + " px" : "Walk radius — off"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Distance the pinned pet strolls around the spot you dropped it"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            value: root.walkRadius
            minimum: 0
            maximum: 500
            step: 25
            onReleased: function(v) { root.saveSetting("walkRadius", Math.round(v)) }
          }

          Text {
            width: parent.width
            text: "Minimum stride — " + root.walkMin + " px"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Shortest distance of one stroll, so the pet does not just shuffle. Capped by the radius"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            value: root.walkMin
            minimum: 0
            maximum: 500
            step: 25
            onReleased: function(v) { root.saveSetting("walkMin", Math.round(v)) }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          Text {
            width: parent.width
            text: "Randomness — " + root.randomness + "%"
            color: root.barForeground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "How often the pet moves on its own, idle actions and strolls alike"
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            value: root.randomness
            minimum: 0
            maximum: 100
            step: 5
            onReleased: function(v) { root.saveSetting("randomness", Math.round(v)) }
          }
        }
        }
      }
    }
  }
}
