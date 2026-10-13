# Yaseen Menubar

A small menu bar manager for the Mac. It hides menu bar icons and shows them with a click.

- An arrow sits in the menu bar. A click on the arrow shows or hides the icons on its left.
- To change the group of an icon, hold Command and drag the icon across the arrow.
- The app needs zero permissions: no Accessibility, no Screen Recording.
- It is a native Swift app. It lives in the menu bar and has no Dock icon.
- It needs macOS 14 or later on an Apple Silicon Mac.
- It replaces Bartender.

## How it works

- The app owns two menu bar icons: the arrow and a thin divider on its left.
- To hide, the app makes the divider 10,000 points long. macOS then pushes each icon on the left of the divider off the screen.
- A left click on the arrow shows the icons. They hide again after 10 seconds. The app waits while the pointer is in the menu bar or a menu is open.
- A dot on the arrow tells that a new icon landed on the hidden side.
- When the app quits or stops, macOS removes the divider and all icons come back.
- While the icons are hidden, the app runs no timer and watches no input.

## Known limits

- On a display with a notch, the icons that do not fit stay behind the notch, also when all icons show. They fit on an external display.
- If the shown group has too many icons, the arrow itself can go behind the notch. Move icons to the hidden group, or remove an icon in System Settings > Menu Bar.
- The app cannot name the icons of other apps. That needs a permission. Thus the dot is an estimate: it shows when the number of hidden icons is higher than before.
- The app counts 2 seconds after an app starts. It does not see an icon that arrives later.

## Build

You need Xcode. The package has no outside dependency.

- `swift build`: build the app for development.
- `swift test`: run the unit tests.
- `scripts/bundle.sh`: make `build/Yaseen Menubar.app` from a release build and sign it.
- `scripts/bundle.sh --dmg`: also make `build/Yaseen-Menubar-<version>-arm64.dmg`.
- `swift scripts/make-icon.swift`: draw the app icon again into `Support/AppIcon.icns`. Run it only after a change to the drawing.

The version is in one place: `CFBundleShortVersionString` in `Support/Info.plist`.

## Install

1. Quit Bartender first. Bartender and this app both hide icons. Do not run them together.
2. Run `scripts/bundle.sh`.
3. Run `scripts/install.sh`. It quits the old copy, puts the app in `/Applications`, and opens it.

## The signature

`scripts/bundle.sh` signs with the certificate "Yaseen Local Signing". With a fixed certificate, each build is the same app for macOS. Set `SIGN_IDENTITY` to use a different name. Set `REQUIRE_SIGN_IDENTITY=1` to make the script fail when the keychain does not have the certificate.

If the keychain does not have the certificate, the script signs ad-hoc and prints this:

```
WARNING: ad-hoc signature. For macOS, each build is then a different app. Run scripts/make-signing-cert.sh one time.
```

### Make the certificate (one time on a new Mac)

1. Run `scripts/make-signing-cert.sh`. It makes the self-signed certificate "Yaseen Local Signing" in your login keychain. If the certificate is there already, the script changes nothing.
2. Check that the keychain has it:

   ```bash
   security find-identity -p codesigning
   ```

   The list must show `"Yaseen Local Signing"`. The text `CSSMERR_TP_NOT_TRUSTED` next to it is normal for a self-signed certificate.
3. Run `scripts/bundle.sh`. The first time, macOS asks if `codesign` can use the key. Enter your login password and click "Always Allow".
4. Check the signature:

   ```bash
   codesign -d -r- "build/Yaseen Menubar.app"
   ```

   The output must name a certificate (`certificate leaf = H"…"`). It must not show `cdhash`.

### Give the certificate to GitHub (one time)

The release workflow signs with the same certificate. It reads two repository secrets.

1. Select a password for the `.p12` file. Then export the certificate and its private key:

   ```bash
   security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12 -P 'YOUR-P12-PASSWORD' -o ~/yaseen-local-signing.p12
   ```

   This command exports all the identities in the login keychain. If the keychain has other identities, use Keychain Access instead: select "Yaseen Local Signing" in "My Certificates", then File, Export Items, format "Personal Information Exchange (.p12)".
2. Add the two secrets with the GitHub CLI. Run these commands in the repository folder:

   ```bash
   base64 -i ~/yaseen-local-signing.p12 | gh secret set SIGN_CERT_P12_BASE64
   gh secret set SIGN_CERT_PASSWORD
   ```

   The second command asks for the value. Paste the password of the `.p12` file.
3. Delete the file:

   ```bash
   rm ~/yaseen-local-signing.p12
   ```

Without the two secrets, the release workflow signs ad-hoc and writes a warning in its log.

## Releases

- No release is cut automatically.
- Set the new version in `Support/Info.plist` (`CFBundleShortVersionString`) and merge it into `main`.
- Tag that commit `vX.Y.Z` and push the tag. `.github/workflows/release.yml` builds the `.dmg` and attaches it to the GitHub release of that tag. It makes the release if it does not exist.
- The workflow fails if the tag is not the version in `Support/Info.plist`.
- `.github/workflows/ci.yml` runs `swift build` and `swift test` on each pull request.

## Origin

The package layout, the scripts, and the workflows come from the Yaseen Screenshot app.
