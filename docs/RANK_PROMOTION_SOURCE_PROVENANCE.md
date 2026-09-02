# Rank promotion asset provenance

This record establishes the technical origin of the nine rank-promotion MP4
files bundled in the iOS app. It does not make a separate claim about music,
font, or other third-party licensing; the product owner must retain any
underlying rights records.

## Verified origin

- Repository: `https://github.com/is4553807/Matths-Official.git`
- Source commit: `2b4e518f670d96e5c85128504faedb38456874ef`
- Source tree: `69b4fe4ecffa773df85dc8ee87e9c812347f6a47`
- Source path: `public/media/rank-motion`
- Commit author: `sangyoonlee2025 <sangyoonlee.2025@computing.smu.edu.sg>`
- Commit time: `2026-08-25T10:45:20+08:00`
- Commit subject: `optimize`
- Remote reachability checked on 2026-08-31: the commit is contained in
  `origin/main` and the named repository's remote `main` head was reachable.

The source commit preserves the same filenames, 1080 × 1920 dimensions,
H.264 High profile, AAC audio, 60 fps, and 360 video frames as the prior iOS
copies. It reduces the combined asset size from approximately 57 MiB to 18 MiB.
Frame-by-frame SSIM against the prior copies ranged from 0.993653 to 0.995950.

## Enforcement

`Matths/RankMotion/rank-promotion-assets.json` records the repository, commit,
path, byte size, and SHA-256 for every tier. Both the build-time verifier and
the in-app performance self-test reject a different provenance field, missing
asset, unexpected filename, byte size, or digest. Release audit evidence only
marks the rank source eligible when this complete record matches.

To reproduce the source check:

```sh
git clone https://github.com/is4553807/Matths-Official.git
git -C Matths-Official checkout 2b4e518f670d96e5c85128504faedb38456874ef
shasum -a 256 Matths-Official/public/media/rank-motion/*.mp4
```
