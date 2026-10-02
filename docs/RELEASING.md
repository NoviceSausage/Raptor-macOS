# Releasing

Every release contains third-party binaries, so the process below deliberately
includes an attribution check. Do not skip step 1.

## 0. Prerequisites

You need the official RAPTOR archive, `raptor_avalonia.zip`. It is **not**
committed to this repository — it is 53 MB of someone else's binaries, and
committing it would bloat every future clone.

Record its checksum so the release can be traced to an exact input:

```bash
shasum -a 256 raptor_avalonia.zip
# compare against UPSTREAM and update if upstream published a new build
```

## 1. Attribution check (required)

RAPTOR is **public domain** under US Air Force policy, so redistribution needs
no permission. This was determined from the official homepage
(<https://raptor.martincarlisle.com/>, *Acknowledgements*), because the upstream
archive ships no licence file. Re-confirm that statement before each release in
case the project's terms change.

Before packaging a new upstream build, confirm:

- [ ] The official homepage still states RAPTOR is public domain.
- [ ] No GPL component has appeared in the Avalonia payload. NClass (the
      GPL-licensed UML designer) belongs to the Windows-only edition; if an
      upstream build ever bundles it, the GPL would then attach to the bundle and
      this check would fail loudly.
- [ ] `UPSTREAM` has no empty author / homepage / licence fields.
- [ ] The author credits inside the new build still match section 1 of
      `THIRD-PARTY-NOTICES.md`. Print them straight out of the About dialog —
      RAPTOR stores that text as separate UTF-16 runs rather than contiguous
      strings, so `tools/extract-credits.sh` walks the byte stream:

      ```bash
      ./tools/extract-credits.sh upstream/publish/raptor.dll
      ```

      If the names changed, update section 1 of `THIRD-PARTY-NOTICES.md`.
- [ ] Any newly bundled dependency appears in `THIRD-PARTY-NOTICES.md`.
      Diff the dependency list to spot additions:

      ```bash
      unzip -p upstream/publish/raptor.deps.json \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); \
          t=list(d["targets"].values())[0]; \
          print("\n".join(sorted(k for k in t if "/" in k)))'
      ```

- [ ] The upstream archive still contains no `LICENSE` / `README`. If it now
      does, mirror those terms into `THIRD-PARTY-NOTICES.md` verbatim (or link
      to them) rather than relying on the homepage statement.

If RAPTOR ever stops being public domain, stop and re-evaluate. Shipping only
the scripts plus a documented, user-run download step is always a safe fallback.

## 2. Set the version

`VERSION` drives `CFBundleVersion` and `CFBundleShortVersionString`.

```bash
echo "1.0.1" > VERSION
```

Use a plain `MAJOR.MINOR.PATCH`. Anything after `-` is stripped before it
reaches `Info.plist`, because Apple requires a numeric-only build version.

Update `CHANGELOG.md`.

## 3. Build and test locally

```bash
./tools/package-macos.sh upstream/publish --zip --dmg
```

Building the `.dmg` runs `hdiutil`, which needs an unsandboxed shell. The Finder
icon layout is applied only when a GUI session is available and is skipped with a
warning otherwise, so this is safe on a headless runner.

Then actually launch it and exercise it — a bundle that opens but cannot run a
program is not a release:

```bash
open build/RAPTOR.app
```

Check:

- [ ] The window opens and the splash/UI renders.
- [ ] The Dock shows the RAPTOR icon, not a generic executable icon.
- [ ] Loading a .NET assembly and starting a decompile works.
- [ ] Image-handling features work (this is what `libgdiplus` is for).
- [ ] No `Fontconfig error` appears when launched from a terminal:

      ```bash
      ./build/RAPTOR.app/Contents/MacOS/RAPTOR
      ```

## 4. Commit and tag

```bash
git add -A
git commit -m "Release 1.0.1"
git tag -a v1.0.1 -m "v1.0.1"
git push origin main --tags
```

Pushing the tag triggers `.github/workflows/release.yml`, which builds the
bundle on a macOS runner and attaches the archive to a draft GitHub Release.

The workflow needs the upstream archive URL in a repository secret because the
archive is not in the repository:

| Secret | Value |
| --- | --- |
| `RAPTOR_UPSTREAM_URL` | Direct download URL of the official `raptor_avalonia.zip` |

If the secret is unset the workflow exits with a warning instead of failing,
so forks stay green.

## 5. Publish the release

1. Open the draft release CI created.
2. Verify the attached assets download and install:
   - `RAPTOR-<version>-macos-arm64.dmg` — mount it, drag the app out, launch it.
   - `RAPTOR-<version>-macos-arm64.zip` — the same bundle for people who prefer a
     plain archive.
3. Paste the relevant `CHANGELOG.md` section into the release notes.
4. Include the attribution footer:

   > RAPTOR is public domain (US Air Force policy), originally developed by and
   > for the US Air Force Academy, and is redistributed here unmodified. This is
   > an unofficial macOS repackaging, not endorsed by the RAPTOR authors. See
   > THIRD-PARTY-NOTICES.md. The .NET 8 Runtime and libgdiplus are required and
   > are not bundled.
5. Publish.

## 6. After publishing

- [ ] Confirm the Gatekeeper instructions in the README still match reality on a
      clean Mac — download the release, and check whether the quarantine prompt
      appears. The DMG and the ZIP behave differently: an app run straight from a
      mounted image is re-checked on every launch, whereas one copied to
      `/Applications` and un-quarantined is not.
- [ ] If a new upstream build replaces the old one, keep the previous release
      available rather than deleting it; users may need to roll back.

## Manual release (no CI)

```bash
./tools/package-macos.sh upstream/publish --zip --dmg
gh release create v1.0.1 \
    build/RAPTOR-1.0.1-macos-arm64.dmg \
    build/RAPTOR-1.0.1-macos-arm64.zip \
    --title "RAPTOR for macOS 1.0.1" \
    --notes-file CHANGELOG.md
```

For the ZIP, `ditto` is used rather than `zip`, because it preserves the
executable bits and bundle metadata; a plain `zip` can produce a bundle that
refuses to launch.
