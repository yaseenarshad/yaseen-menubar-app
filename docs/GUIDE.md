<p align="center">
  <img src="assets/icon.png" width="96" alt="The app icon: an indigo square with a white Y and a small menu bar">
</p>

# The guide

How to install and use Yaseen Menubar, with each detail. The short version is on the [first page](../README.md).

## Install from a release

1. Quit any other menu bar manager first. See ["Two managers at once"](#two-managers-at-once).
2. Open the [releases page](https://github.com/yaseenarshad/yaseen-menubar-app/releases/latest) and download `Yaseen-Menubar-<version>-arm64.dmg`.
3. Open the `.dmg`. Drag "Yaseen Menubar" onto the "Applications" link.
4. Start the app from `/Applications`. macOS stops it the first time, because the app is not notarized.
5. Open System Settings, then Privacy & Security. Click "Open Anyway" next to "Yaseen Menubar". You do this one time.
6. The arrow comes in the menu bar. A small window shows the one rule, below the heading "How to hide an icon". Click "Done".

The app needs no macOS permission. It does not ask for one.

### If you do not see the arrow

A full menu bar can put an icon behind the notch of a MacBook.

- At its first start, the app asks macOS for a place 420 points from the right edge of the screen. That is on the right of the notch.
- With too many icons on the right of the arrow, the arrow itself can go behind the notch. Then remove an icon in System Settings > Menu Bar.
- To move the arrow, hold Command and drag it.

## Use

### The arrow

- A click on the arrow hides each icon on its left. A second click shows them.
- The arrow points left while icons are hidden. It points right while they show.
- At the first start, the icons stay shown until you close the small window with the rule. At each later start, the app hides the icons at once.

### Choose the side of an icon

Hold Command and drag an icon across the arrow.

- **Left of the arrow:** the icon hides with the others.
- **Right of the arrow:** the icon always shows.

There is an empty gap of 17 points on the left of the arrow. That is normal. You can drop an icon in the gap or on the left of it. The icon hides in the two cases.

### Hide again after a delay

- After you show the icons, they hide again after 10 seconds.
- The app waits while your pointer is in the menu bar.
- The app waits while a menu is open, for one minute at most.
- You select the delay in the settings: 5 seconds, 10 seconds, 30 seconds, or Never.

### What the dot means

A small dot on the arrow tells that a new icon is on the hidden side. Click the arrow to see the icon. The click also removes the dot.

The dot is an estimate:

- The app cannot name the icons of other apps. That needs a permission. The app only counts the hidden icons, and a count that is higher than before gives the dot.
- The app counts one time, 2 seconds after an app starts. It does not see an icon that arrives later.
- The app shows no dot in the first minute after its own start. Many apps start at login.
- With more than one display, a display that connects can give one false dot.

### Where the settings are

Right-click the arrow, or hold Control and click it. The menu has three rows: "Settings…", "How to hide an icon", and "Quit Yaseen Menubar".

"Settings…" has three rows:

- **Open at login:** the app turns this on at its first start. The switch turns it off. It works only in the installed app.
- **Hide again after:** 5 seconds, 10 seconds, 30 seconds, or Never. The default is 10 seconds.
- **Hotkey:** see below.

### The hotkey

The hotkey is optional. There is none until you record one.

1. Open the settings and click "Record hotkey".
2. Press the keys. The combination needs Command, Control or Option.
3. The button now shows the keys. "Clear" removes the hotkey.

The hotkey does the same as a click on the arrow. If a different app uses the keys already, the window says "That hotkey is in use." Esc stops the recording.

### How to quit

Right-click the arrow and select "Quit Yaseen Menubar".

### What happens when the app quits

Each icon comes back. The app hides icons with its own invisible menu bar item. When the app quits or stops, macOS removes that item, and the icons go back to their places.

The app does not move, change or delete the icon of a different app.

## The limits

### The notch

The app does not make the menu bar wider.

- On a laptop screen with a notch, the icons that do not fit stay behind the notch, also when you show all icons. They fit on an external display.
- The icons on the right of the arrow stay in view. Keep that group small.
- With too many icons on the right of the arrow, the arrow itself can go behind the notch. Then move icons to the left of the arrow, or remove an icon in System Settings.

### An icon that must never show

The app has two sides only: hidden, and always shows. For an icon that must never show, use macOS: System Settings > Menu Bar > "Allow in the Menu Bar".

### Two managers at once

Do not run this app together with a different menu bar manager. The two move the same icons, and the result is not stable. Quit the other one first. Also turn off its "open at login" setting, or it comes back after a restart.

A second copy of this app is not a problem. It quits at once, so the menu bar never has two arrows.

### What is not checked yet

Version 0.1.3 is tested on one Mac with macOS 26.

- **Checked on that Mac:** hide and show, the drag, the right-click menu, and the settings window.
- **Not checked yet on a real Mac:** the hotkey, open at login after a restart, and the dot.

If something does not work on your Mac, [open an issue](https://github.com/yaseenarshad/yaseen-menubar-app/issues).
