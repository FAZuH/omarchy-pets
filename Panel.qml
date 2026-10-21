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
    var raw = String(root.setting("petsDir", "~/.omarchy-pets/pets"))
    return raw === "~" || raw.indexOf("~/") === 0 ? home + raw.slice(1) : raw
  }
  readonly property var settingKeys: ["petId", "petsDir", "smooth", "pinned", "pinnedX", "pinnedY", "pinnedScale", "randomBehavior", "animate", "walk", "walkRadius", "walkMin", "randomness"]
  readonly property string petId: String(root.setting("petId", ""))
  readonly property bool smoothScaling: root.setting("smooth", true) === true
  readonly property bool animate: root.setting("animate", true) === true
  readonly property bool randomBehavior: root.setting("randomBehavior", true) === true
  readonly property bool pinned: root.setting("pinned", true) === true
  // The pet lives on the desktop while the panel is closed; an open panel shows it inside.
  readonly property bool onDesktop: pinned && !opened
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
  onPinnedChanged: if (!pinned) stopWalk()
  onOnDesktopChanged: if (!onDesktop) stopWalk()
  onWalkChanged: if (!walk) stopWalk()

  function stopWalk() {
    walkMoving = false
    walkDx = 0
    walkDy = 0
  }

  function open() {
    root.controller.show()
  }

  function toggle() {
    if (!opened) open()
    else close()
  }

  function dragPet(dx, dy) {
    if (!onDesktop) return
    dragDx = petX + dx - restX
    dragDy = petY + dy - restY
  }

  function dropPet() {
    if (!onDesktop) return
    var x = petX
    var y = petY
    dragDx = 0
    dragDy = 0
    stopWalk()
    walkDwell = Sprite.walkDwellMs(Math.random()) * Sprite.randomnessFactor(root.randomness)
    saveSettings({ pinnedX: x, pinnedY: y })
  }

  function currentSettings() {
    return {
      petId: String(root.setting("petId", "")),
      petsDir: String(root.setting("petsDir", "~/.omarchy-pets/pets")),
      smooth: root.setting("smooth", true) === true,
      pinned: root.setting("pinned", true) === true,
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

  // The shell replaces the whole entry, not one key: send every known setting.
  function saveSettings(values) {
    var entry = { id: moduleName }
    var current = currentSettings()
    for (var i = 0; i < settingKeys.length; i++) entry[settingKeys[i]] = current[settingKeys[i]]
    var changed = false
    for (var name in values) {
      if (!(name in entry)) continue
      if (entry[name] === values[name]) continue
      entry[name] = values[name]
      changed = true
    }
    if (!changed) return
    var shell = bar ? bar.shell : null
    if (!shell || typeof shell.updateEntryInline !== "function") {
      console.warn("omarchy-pets: cannot save " + JSON.stringify(values) + ": bar.shell.updateEntryInline unavailable")
      return
    }
    if (shell.updateEntryInline(moduleName, entry)) console.log("omarchy-pets: saved " + JSON.stringify(values))
    else console.warn("omarchy-pets: shell refused " + JSON.stringify(values))
  }

  function saveSetting(key, value) {
    var values = {}
    values[key] = value
    saveSettings(values)
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
    parent: root.onDesktop ? pinnedSlot : panelSlot
    x: root.onDesktop ? root.petX : 0
    y: root.onDesktop ? root.petY : 0
    width: root.onDesktop ? Math.round(192 * root.pinnedScale) : 192
    height: root.onDesktop ? Math.round(208 * root.pinnedScale) : 208

    PetSprite {
      id: sprite
      anchors.fill: parent
      sheetUrl: root.currentPet ? root.currentPet.sheetUrl : ""
      sheetLabel: root.currentPet ? root.currentPet.name : ""
      smoothScaling: root.smoothScaling
      cellScale: root.onDesktop ? root.pinnedScale : 1
      running: (root.opened || root.onDesktop) && root.animate && root.currentPet !== null
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
      running: root.onDesktop && root.animate && root.walk && root.walkRadius > 0 && root.currentPet !== null

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
  }

  PanelWindow {
    id: pinnedWindow
    visible: root.onDesktop && root.currentPet !== null
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
    // Whole window while engaged, so a fast drag cannot escape.
    mask: Region {
      x: sprite.engaged ? 0 : stage.x
      y: sprite.engaged ? 0 : stage.y
      width: sprite.engaged ? pinnedWindow.width : stage.width
      height: sprite.engaged ? pinnedWindow.height : stage.height
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

      // The card is capped at the screen; what does not fit scrolls.
      Flickable {
        id: cardScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: cardScroll.width
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
          textFormat: Text.PlainText
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
          textFormat: Text.PlainText
          text: "No pets in " + root.petsDir + "\nGet omarchy-pets from omarchy-pets.com/cli, then run omarchy-pets install <id>"
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
            onClicked: root.saveSettings({ petId: modelData.name })
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

        Button {
          width: parent.width
          leftAlign: true
          iconText: "\uf08e"
          text: "Open omarchy-pets.com"
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: Quickshell.execDetached(["omarchy", "launch", "browser", "https://omarchy-pets.com"])
        }

        Toggle {
          width: parent.width
          label: "Show on desktop"
          description: "Stays on the desktop when the panel closes; drag it anywhere"
          checked: root.pinned
          foreground: root.barForeground
          fontFamily: root.fontFamily
          onClicked: root.saveSetting("pinned", !root.pinned)
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
            var values = { walk: !root.walk }
            if (values.walk && root.walkRadius === 0) values.walkRadius = 150
            root.saveSettings(values)
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
