# Redacted failure fixtures

Fixtures contain synthetic observations only. IPv4 uses RFC 5737 documentation ranges, IPv6 uses `2001:db8::/32`, and subscription hosts use `.invalid`.

Every JSON fixture declares:

- a stable `id` and diagnostic `kind`;
- `contains_sensitive_data: false`;
- observations needed for deterministic classification;
- one `expected_classification`.

`scripts/validate_skill.py` rejects missing scenarios, malformed fixtures, unexpected classifications and likely production addresses or credentials.

The conntrack text fixture covers an established UDP flow and an unanswered TCP handshake. It is consumed offline; tests never contact a real server.
