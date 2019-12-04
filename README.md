# selfhosting-tools/nsd-docker

[![Build Status](https://travis-ci.org/selfhosting-tools/nsd-docker.svg?branch=master)](https://travis-ci.org/selfhosting-tools/nsd-docker)

## What is this software

[NSD](https://www.nlnetlabs.nl/projects/nsd/about/) is an authoritative only, high performance, simple and open source name server released under the BSD licence.
This work is originally based on [hardware/nsd-dnssec](https://github.com/hardware/nsd-dnssec).

### Features

- Lightweight & secure image (based on Alpine, multi-stage build, no root process)
- Latest NSD version with hardening compilation options
- Helper scripts for generating ZSK and KSK keys, DS-Records management and zone signature

### Run with Docker-compose

```docker-compose
version: '3.7'

services:
  nsd:
    container_name: nsd
    restart: always
    image: selfhostingtools/nsd-docker:latest
    read_only: true
    tmpfs:
      - /tmp
    volumes:
      - /mnt/nsd/conf:/etc/nsd
      - /mnt/nsd/zones:/zones:ro
      - /mnt/nsd/db:/var/db/nsd
    ports:
      - 53:53
      - 53:53/udp
```

`/etc/nsd` can be mounted read-only after the first run.

#### Configuration example

Put your dns zone file in `/mnt/nsd/zones/db.domain.tld`.

```zone
$ORIGIN domain.tld.
$TTL 3600

; SOA
@       IN      SOA    ns1.domain.tld. hostmaster.domain.tld. (
                                        2016020202 ; Serial
                                        7200       ; Refresh
                                        1800       ; Retry
                                        1209600    ; Expire
                                        86400 )    ; Minimum

; NAMESERVERS
@                   IN                NS                   ns1.domain.tld.
@                   IN                NS                   ns2.domain.tld.

; A RECORDS
@                   IN                A                    IPv4
hostname            IN                A                    IPv4
ns1                 IN                A                    IPv4
ns2                 IN                A                    IPv4

; CNAME RECORDS
www                 IN                CNAME                hostname

; MAIL RECORDS
@                   IN                MX          10       hostname.domain.tld.

...
```

Put the nsd config in `/mnt/nsd/conf/nsd.conf`.

```yaml
server:
  server-count: 1
  verbosity: 2
  hide-version: yes
  zonesdir: "/zones"

zone:
  name: domain.tld
  zonefile: db.domain.tld.signed
```

Check the [documentation](https://www.nlnetlabs.nl/documentation/nsd/) to see all options.

#### Check the configuration

Check your zone and nsd configuration:

```sh
cd /mnt/nsd
docker run -it --rm -v $(pwd)/zones:/zones selfhostingtools/nsd-docker nsd-checkzone domain.tld /zones/db.domain.tld
docker run -it --rm -v $(pwd)/conf:/etc/nsd selfhostingtools/nsd-docker nsd-checkconf /etc/nsd/nsd.conf
```

#### Environment variables

You may want to change the running user:

| Variable | Description  | Type       | Default value |
| -------- | -----------  | ----       | ------------- |
| **UID**  | nsd user id  | *optional* | 991           |
| **GID**  | nsd group id | *optional* | 991           |

### Generating DNSSEC keys and signed zone

Generate ZSK and KSK keys with ECDSAP384SHA384 algorithm (it may take some time; you can install `haveged` in your base system to speed it up):

```sh
docker-compose exec nsd keygen domain.tld

Generating ZSK & KSK keys for 'domain.tld'
Done.
```

Then sign your dns zone (default expiration date is 1 month):

```
docker-compose exec nsd signzone domain.tld

Signing zone for domain.tld
NSD configuration rebuild... reconfig start, read /etc/nsd/nsd.conf
ok
Reloading zone for domain.tld... ok
Notify slave servers... ok
Done.

# or set custom RRSIG RR expiration date :

docker-compose exec nsd signzone domain.tld [YYYYMMDDhhmmss]
docker-compose exec nsd signzone domain.tld 20170205220210
```

:warning: **Do not forget to add a cron task to increment the serial and sign your zone periodically to avoid the expiration of RRSIG RR records!**

Show your DS-Records (Delegation Signer):

```sh
docker-compose exec nsd ds-records domain.tld

> DS record 1 [Digest Type = SHA1] :
domain.tld. 600 IN DS xxxx 14 1 xxxxxxxxxxxxxx

> DS record 2 [Digest Type = SHA256] :
domain.tld. 600 IN DS xxxx 14 2 xxxxxxxxxxxxxx

> Public KSK Key :
domain.tld. IN DNSKEY 257 3 14 xxxxxxxxxxxxxx ; {id = xxxx (ksk), size = 384b}
```

Restart the DNS server to take the changes into account:

```sh
docker-compose restart nsd
```

## Build the image

Build-time variables:

- **NSD_VERSION** : version of NSD
- **GPG_FINGERPRINT** : fingerprint of signing key
- **SHA256_HASH** : SHA256 hash of NSD archive
