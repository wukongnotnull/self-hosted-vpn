# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-02

### Added

- Safety-gated deployment and troubleshooting state machine.
- Focused OpenVPN, 3x-ui, Hysteria2, Reality, connection logging, rollback and case-study references.
- Read-only preflight, client, protocol and acceptance diagnostics with stable JSON and exit codes.
- Automatic report redaction, independent UDP echo, fixed-size test generation and conntrack outcome logging.
- Synthetic failure fixtures, repository validation, offline tests, ShellCheck and Markdown CI.
- Tested support matrix, fresh-VM checklist, version policy and release process.

### Changed

- Replaced root-password-in-chat guidance with SSH keys, non-root sudo, host fingerprint verification and restricted management access.
- Preserved `reference.md` as a compatibility index while moving detailed content under `references/`.
- Distinguished IPv4 UDP return loss from large-packet checksum corruption.

### Security

- Removed production addresses and credential-shaped examples.
- Required explicit confirmation and rollback preparation before mutations.
- Limited insecure TLS guidance to a single self-signed Hysteria2 node.

[Unreleased]: https://github.com/wukongnotnull/self-hosted-vpn/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/wukongnotnull/self-hosted-vpn/releases/tag/v1.0.0
