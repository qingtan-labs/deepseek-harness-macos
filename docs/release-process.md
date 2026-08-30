# Release process

## 1. Prepare

1. Update every version source listed in [maintenance.md](maintenance.md).
2. Finish English and Simplified Chinese release notes.
3. Confirm the working tree contains no generated files or secrets.
4. Run the full regression matrix for changed areas.

## 2. Build and verify

```sh
./scripts/build-release.command
shasum -a 256 -c dist/DeepSeek-Harness-<version>-macOS.dmg.sha256
hdiutil verify dist/DeepSeek-Harness-<version>-macOS.dmg
```

Also inspect the contained app with `codesign --verify --deep --strict` and verify both `arm64` and `x86_64` architectures with `lipo -archs`.

## 3. Publish

1. Merge the release commit to `main`.
2. Create tag `v<version>` from that exact commit.
3. Create a GitHub Release with the matching title and bilingual notes.
4. Upload the DMG and `.sha256` file; mark the release as latest. Present the DMG as the primary installer.
5. Test both asset downloads from a signed-out browser and run the checksum again.
6. Confirm the README's latest-download link resolves directly to the published DMG.

Do not replace an asset silently. If a published artifact is wrong, document the problem and publish a corrected version/tag.

## 4. Post-release

- Verify badges, release links, Issues, and the security reporting link.
- Install on a clean supported Mac account when possible.
- Move planned changes to the next milestone and keep the changelog unreleased section ready.
