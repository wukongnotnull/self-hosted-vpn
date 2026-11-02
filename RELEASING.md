# Release process

## Version policy

The skill uses Semantic Versioning:

- Patch: corrections that do not change the supported workflow or report schema.
- Minor: backward-compatible diagnostics, references or supported environments.
- Major: renamed skill entry point, incompatible JSON/report schema, removed workflow, or changed safety contract.

External software versions in [SUPPORT.md](SUPPORT.md) are tested baselines, not permission to skip runtime probes. Prefer feature detection. When a feature cannot be confirmed, stop instead of guessing from the version.

## Dependency policy

- The skill itself has no runtime package installation.
- Shell diagnostics use POSIX utilities plus Bash; JSON and networking helpers use the Python standard library.
- CI pins the Markdown linter version.
- GitHub Actions major versions are reviewed during each release.
- 3x-ui, Xray, OpenVPN Access Server, client and core upgrades require release-note review and a fresh-VM validation before the support matrix changes.

## Prepare

1. Start from an up-to-date `main` with a clean working tree.
2. Update `CHANGELOG.md`, [SUPPORT.md](SUPPORT.md) and the last-verified date.
3. Run:

   ```bash
   python3 scripts/validate_skill.py
   python3 -m unittest discover -s tests -v
   bash -n scripts/*.sh
   shellcheck -x scripts/*.sh
   npx --yes markdownlint-cli2@0.18.1
   ```

4. Complete the fresh-VM and negative-case checklists in [SUPPORT.md](SUPPORT.md).
5. Confirm the pull request's `validate` workflow is green.
6. Review the full diff for production addresses, credentials, account names and subscription paths.
7. Merge through a pull request. Do not tag an unmerged commit.

## Tag and publish

Create an annotated, immutable tag from the verified `main` commit:

```bash
git switch main
git pull --ff-only
git tag -a v<MAJOR.MINOR.PATCH> -m "self-hosted-vpn v<MAJOR.MINOR.PATCH>"
git push origin v<MAJOR.MINOR.PATCH>
gh release create v<MAJOR.MINOR.PATCH> \
  --title "self-hosted-vpn v<MAJOR.MINOR.PATCH>" \
  --notes-from-tag
```

Verify a fixed-version installation in a disposable directory after publishing.

## Release rollback

Do not move or overwrite a published tag.

If a release is unsafe:

1. Mark the GitHub release as deprecated and state the last safe tag.
2. Prepare a patch release that reverts the unsafe change.
3. Run the full validation and fresh-VM checks.
4. Publish a new immutable tag.

Consumers can remove the current installation and reinstall the last safe tag using the commands in [README.md](README.md).
