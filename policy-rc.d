#!/bin/sh

# dpkg-reconfigure: always allow
[ -n "$DEBCONF_RECONFIGURE" ] && exit 0

# Deny if any ancestor process is unattended-upgrade
pid=$$
while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'unattended-upgrade'; then
        echo "policy-rc.d: '$2 $1' deferred (unattended-upgrades)" >&2
        exit 101
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done

exit 0