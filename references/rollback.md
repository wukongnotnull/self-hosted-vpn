# Rollback

Prepare rollback before approving a mutation. A backup is valid only after its path, owner, permissions and restore command have been checked.

## General sequence

1. Keep the current SSH session and an independent recovery path open.
2. Record services, listeners, routes and firewall counters.
3. Create a timestamped backup beside the managed artifact or in a root-only backup directory.
4. Write the exact inverse command before applying the change.
5. Change one layer.
6. Run acceptance.
7. On failure, restore that layer immediately and re-run the baseline checks.

Do not continue to a second change while the first is unverified.

## 3x-ui and Xray

Back up:

- panel database;
- exported inbound JSON;
- persistent Xray template;
- installed 3x-ui and Xray version identifiers.

Rollback order:

1. Put the client on the unaffected node.
2. Restore the persistent template or database from the timestamped backup.
3. Restore the previous binaries only if the failure followed an upgrade.
4. Restart x-ui.
5. Verify the generated running configuration and both listeners.

Editing generated runtime JSON is not a durable rollback.

## Firewall and MTU

Before adding a system firewall rule, save the exact command and construct its inverse by changing insertion/addition to deletion with otherwise identical arguments.

For cloud firewalls, record the rule identifier and previous state. Removing a system rule does not remove the provider rule, and vice versa.

When reverting an MTU workaround:

1. Remove the exact address-family-specific firewall rule.
2. Restore the previous Xray template.
3. Restart x-ui through the unaffected path.
4. Confirm small and large packet behavior returns to the baseline.

Do not flush an entire firewall table to remove one rule.

## Sysctl

Save current values and the exact persistent file before editing. Roll back both the live value and the persistent file. Deleting a file is safe only if the file was created by this change and its absence was the recorded baseline.

## Client profile

Back up the enhancement script and record the active profile identifier. Restore the script, refresh the subscription, reload the running core and verify the runtime configuration. Editing only the downloaded YAML is not a rollback because refresh may replace it.

## IPv6 fallback

To return Hysteria2 to IPv4:

1. Restore the previous client server field or enhancement script.
2. Refresh and reload the client.
3. Verify IPv4 UDP end to end.
4. Remove the IPv6 cloud firewall rule only after no client uses it.

Do not disable server IPv6 merely to undo one node override.

## OpenVPN Access Server

Save the previous Server Config Directives. Restore the previous text, update the running server, then disconnect and reconnect the client. Confirm both general Internet and mainland test routes.

## Rollback completion

The rollback is complete only when:

- baseline listeners and routes are restored;
- the original connection path works;
- no temporary listener or broad firewall rule remains;
- service restart and client refresh preserve the restored state;
- the incident report records the failed change and evidence.
