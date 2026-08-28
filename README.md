### Debian preseed repo for DATUM box

This image takes care of installing [Debian trixie](https://www.debian.org) automatically alongside [Bitcoin Knots](https://tracker.debian.org/pkg/bitcoin-knots) and [DATUM Gateway](https://tracker.debian.org/pkg/datum-gateway) directly from the [stable backport](https://backports.debian.org) repository of Debian.
The behavior of the installer is to automatically select the biggest disk.
The default user is `box` and the password is `datumbox` (It will automatically ask you to change it upon first login).

Depedency:
```
sudo apt install -y xorriso wget gzip
```

Build:
```
./build.sh [args]
```

`-a <bitcoin address>` if set, this address will be automatically configured as `pool_address` for DATUM Gateway

`-c [amd64/arm64]` required, specify which CPU architecture that should be built.

`-s "<SSH pubkey>"` if set, this public key will be allowed for ssh connections for the `box` user. Password login will be disabled.

You can clean the build files with:
```
./build.sh clean
```