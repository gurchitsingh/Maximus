# Release signing (Android)

**Status.** Release builds are now signed with an **upload key** read from `app/android/key.properties`. They are
never signed with the debug key. If `key.properties` is missing, a release build fails. Debug builds are unchanged.
Play rules below are **UNVERIFIED** unless marked otherwise: I did not read the official pages.

## What was proven (2026-11-25, real output)

A throwaway keystore (30-day validity, in a temp folder outside the repo) was created, and a temporary
`key.properties` pointed at it. Both are deleted now. The real keystore does not exist yet.

**1. Without `key.properties`, `flutter build appbundle --release` fails:**

```
FAILURE: Build failed with an exception.
* What went wrong:
RELEASE SIGNING: app/android/key.properties not found. Release builds are never signed with the debug key. Create the upload key and key.properties as described in docs/RELEASE_SIGNING.md.
BUILD FAILED in 2m 42s
Gradle task bundleRelease failed with exit code 1
```

**2. With the throwaway key, the build succeeds:**

```
✓ Built build\app\outputs\bundle\release\app-release.aab (61.5MB)
```

**3. `jarsigner -verify -verbose -certs app-release.aab`** (lines filtered, counted with `uniq -c`):

```
    426       X.509, CN=THROWAWAY TEST KEY, O=Test, C=IN
      1 - Signed by "CN=THROWAWAY TEST KEY, O=Test, C=IN"
      1 jar verified.
      1 This jar contains entries whose signer certificate is self-signed.
```

A search of the same output for `Android Debug` found no match, so the bundle carries the throwaway key and not
the debug key. "Self-signed" is normal for an upload key.

## Identifiers found (not changed)

| Item | Value |
|---|---|
| `applicationId` | `com.gurchit.maximus.maximus` |
| `namespace` | `com.gurchit.maximus.maximus` |
| `versionName` / `versionCode` | from `app/pubspec.yaml` (`version: 1.0.0+1` means name 1.0.0, code 1) via Flutter defaults |

The app name and package id are still open owner decisions. The package id is permanent once uploaded (see
`docs/store/LAUNCH_CHECKLIST.md`). Decide before the first upload. Raise the `+N` in `pubspec.yaml` for every upload.

## Create the real upload key (owner, once)

Do this on your own machine, **outside the repo and outside OneDrive-synced folders**. Example folder:
`C:\keys\maximus\` (not under `Desktop`, `Documents` or `OneDrive`).

```
keytool -genkeypair -v -keystore C:\keys\maximus\upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

`keytool` asks for the keystore password, the key password and your name fields. **Type the passwords at the
prompt.** Do not put them on the command line (no `-storepass`) and do not store them in any file in the repo.
Save them in a password manager. `keytool` is in the JDK (`bin\keytool.exe`).

## `key.properties` template

Create `app/android/key.properties` (gitignored, never commit it):

```
storeFile=C:/keys/maximus/upload-keystore.jks
storePassword=<your keystore password>
keyAlias=upload
keyPassword=<your key password>
```

Keys: `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Use forward slashes in `storeFile`. A relative path is
resolved against `app/android/`. This file holds passwords in plain text, so keep it only on your machine, and
outside any synced folder if you can. If you must keep it in the repo folder on OneDrive, it will sync to the cloud.

Then build: `flutter build appbundle --release` from `app/`. The bundle is at
`app/build/app/outputs/bundle/release/app-release.aab`.

## Where to keep the key

- Primary: `C:\keys\maximus\upload-keystore.jks`, outside the repo and outside OneDrive.
- Backup: one copy on an offline drive (USB stick) kept somewhere safe, plus the passwords in a password manager.
  Do not email the keystore, and do not put it in OneDrive, Google Drive or Git.
- Ignore rules already in place: `key.properties`, `*.jks` and `*.keystore` are gitignored (checked with
  `git check-ignore`).

## If the key is lost (all UNVERIFIED)

Written from memory. Check the official page before relying on it:
https://support.google.com/googleplay/android-developer/answer/9842756 (where to check, UNVERIFIED).

- With **Play App Signing** (the default for new apps, UNVERIFIED), Google holds the app signing key and you hold
  only the upload key. A lost upload key can reportedly be reset through Play Console: create a new key, export its
  certificate with `keytool`, and request an upload key reset. Expect a wait before the new key is accepted. The
  exact steps and delay are UNVERIFIED.
- If you do **not** use Play App Signing, a lost app signing key cannot be replaced for the existing listing
  (UNVERIFIED): you would have to publish a new app under a new package name.
- Keep the upload key and the app signing key different (UNVERIFIED).

## Optional later step: minify / shrink (not enabled)

`isMinifyEnabled` and `isShrinkResources` are **off**. Turning them on can shrink the bundle but can break
reflection-based plugins at runtime. It needs ProGuard/R8 rules and a full test of a release build on the emulator
(sign-in, sync, chat, TTS, deletion) before shipping. Do it only after that test.
