# SMB Fileserver Container with LDAP support

Containerized smb fileserver setup with LDAP-backed authentication, designed primarily for homelab environments.

This container provides following highlevel features:

* LDAP-based authentication and automatic NSS account resolution
* dynamic Samba configuration through environment variables & mountable files.
* Out of the Box Service Discovery
* multi-service runtime inside a single container (not always is a multiprocess image a bad idea!)

The project is developed as a personal homelab project and is not intended to compete with enterprise NAS distributions or hardened production storage appliances.

> [!WARNING]
> This project is developed primarily for personal homelab usage, optimized for flexibility and LDAP experimentation and intentionally configurable and hackable
>
> It is **not** currently security audited, enterprise supported, intended for internet exposure, tested for large-scale multi-tenant environments. Use it at your own risk.

## Project goals

The primary motivation behind this project was just learning now things, as my current tecstack got a bit stale.
I learned so much from doing this :).

Further my second goal is to enable my netshare to authenticate against LDAP identities managed in Authentik without requiring local unix users to be statically provisioned inside the container.

Unfortunally, the LDAP provider from Authentik does not support the samba.schema. I forked and modded the LDAP provider. The code is located here: [https://github.com/mariokellner/authentik-ldap-samba-mod](https://github.com/mariokellner/authentik-ldap-samba-mod). This is far from perfect and a bit "hacky", but it works.

## Architecture

### Runtime Components

The container intentionally runs multiple tightly coupled services inside one runtime environment.

Included services:

| Component      | Purpose                        |
| -------------- | ------------------------------ |
| `smbd`         | SMB file server                |
| `nmbd`         | NetBIOS name services          |
| `nslcd`        | LDAP-backed NSS/PAM resolution |
| `avahi-daemon` | mDNS / Bonjour advertisement   |
| `wsdd2`        | Windows WS-Discovery           |
| `supervisord`  | process supervision            |

This is a deliberate design choice. And it is my choice. The involved services:

* share runtime state
* arent designed to work together on different servers
* expose a unified network identity
* operate as a tightly coupled Samba appliance

## Features

### LDAP Authentication

Supports LDAP-backed authentication using: Samba `ldapsam` and NSS account resolution via `nslcd`

Any LDAP provider with samba.schema is supported, like:

* modded Authentik LDAP Provider (primary target)
* OpenLDAP
* FreeIPA

### Dynamic Configuration over ENV variables

The container dynamically generates Samba configuration using environment variables.

#### Global Parameters

```yaml
SMBGLOBAL_workgroup: HOMELAB
SMBGLOBAL_map_to_guest: Bad User
SMBGLOBAL_someglobalsection: |
  follow symlinks = yes
  unix extensions = no
  acl allow execute always = yes
```

#### Custom smb.cnf file

You can provide a custom smb.conf with a mount to `etc/samba/conf.d/smb.user.conf`

```yaml
volumes:
  - ./smb.user.conf:/etc/samba/conf.d/smb.user.conf:ro
```

#### Dynamic Share Definitions

Shares can be declared declaratively through environment variables too.

```yaml
SMBSHARE_ENTRY_1_name: Data
SMBSHARE_ENTRY_1_path: /mnt/data
SMBSHARE_ENTRY_1_read_only: no
SMBSHARE_ENTRY_1_writable: yes
SMBSHARE_ENTRY_1_share_config: |
  force group = smbshr
  public = yes
```

#### Time Machine Support

Basic Apple Time Machine support is available.
Avahi advertisement for `_adisk._tcp`, `_smb._tcp` and `_device-info._tcp`

## Container Configuration

### Required Environment Variables

As this is an LDAP Container, basic LDAP infromation needs to be provided asa environment variables.

| Variable                 | Description        |
| ------------------------ | ------------------ |
| `LDAP_AK_URI`            | LDAP server URI    |
| `LDAP_BASE_DN`           | LDAP base DN       |
| `LDAP_ADMIN_DN_USERCN`   | LDAP bind user CN  |
| `LDAP_ADMIN_DN_PASSWORD` | LDAP bind password |

### Optional Environment Variables

| Variable | Default |
| - | - |
| `LDAP_USER_SUF` | `users` |
| `LDAP_GROUPS_SUF`  | `groups` |
| `LDAP_ACCESS_FILTER_USER` | `(objectClass=user)` |
| `LDAP_FILTER_GROUP` | `(objectClass=group)` |
| `SHARENAME` | not set<br />when set, shorthand for assigning `netbios` and hostname to all services |
| `GUEST_USERNAME` | not set<br />when set, shorthand for adding guest account to global smb.conf: <br />`guest account = {val}, map to guest = Bad User, guest ok = Yes` <br /> Please note: the default account is "nobody". Make sure you add a dummy account corresponding to the used guest name. |

### Global SMB Configuration

Set global smb configuration through the two possiblities outlined in the [feature part](#features) (SMBGLOBAL_* or mount custom file)

If you use `SMBGLOBAL_` you can specify multiline properties. It enables to quickly provide an own smb.cnf file to the container without volume mounts. Can be usefull in some application where you cannot have additional configfiles within the repository, as it is in portainer ce...

### Share configuration

For a share you will need a volume mount and atleast one env variable so the entrypoint script can generate the config files for it.

For a Share to be defined you can use the following syntax for the environment variable:
`SMBSHARE_ENTRY_{ALPHANUMERIC_ID}_{property}`
Multiline is supported too. In that case the keyname is ommited:

Here is an example:

```yaml
SMBSHARE_ENTRY_1_name: Privat %U
SMBSHARE_ENTRY_1_path: /mnt/homes/%U
SMBSHARE_ENTRY_1_homes: True

SMBSHARE_ENTRY_2_name: Daten
SMBSHARE_ENTRY_2_path: /mnt/public
SMBSHARE_ENTRY_2_global: |
  force group = smbshr
  creation mask = 0664
```

You have to specify atleast attribute: `path` as `SMBSHARE_ENTRY_X_path` which should point to a volume mount.
Anything else can be defined as multiline variable.

The following properties will be interpreted as special variable when provided as `SMBSHARE_ENTRY_X_Y`:

| Variable | Description |
| - | - |
| `SMBSHARE_ENTRY_X_name`: (string) | overwrite the sharename `{ALPHANUMERIC_ID}`. |
| `SMBSHARE_ENTRY_X_public`: yes | synonym for guest ok |
| `SMBSHARE_ENTRY_X_guest_ok`: yes | will enable guest access and add `public`, `writeable`, `available` to the share definition |
| `SMBSHARE_ENTRY_X_homes`: (if set) | Will add preroot script to the share definition to automaticly create new user folder. |
| `SMBSHARE_ENTRY_X_timemachine`: yes | will enable the the time machine feature by creating the smb & avahi configuration |

The macro `%U` is supported.

If you define a share there is always following defaults included:

```ini
browsable = yes
read only = no
```

## Example Docker Compose

```yaml
services:
  samba:
    #image: [...] # need to decide where i host the public image

    network_mode: host

    restart: unless-stopped
        ulimits:
    
    nofile:
        soft: 65536
        hard: 65536

    cap_add:
      - CAP_NET_ADMIN
    
    network_mode: host

    ports:
      - 137:137/udp
      - 139:139/tcp
      - 445:445/tcp
      - 3702:3702/udp
      - 3702:3702/tcp
      - 5354:5353/udp
      - 5354:5353/tcp
      - 5355:5355/udp
      - 5355:3555/tcp

    environment:
      LDAP_AK_URI: ldap://ldap.example.internal:389
      LDAP_BASE_DN: dc=example,dc=internal
      LDAP_ADMIN_DN_USERCN: ldapservice
      LDAP_ADMIN_DN_PASSWORD: supersecret

      SMBGLOBAL_workgroup: HOMELAB

      SMBSHARE_ENTRY_1_name: Data
      SMBSHARE_ENTRY_1_path: /mnt/data
      SMBSHARE_ENTRY_1_public: yes

      SMBSHARE_ENTRY_2_name: User Share
      SMBSHARE_ENTRY_2_path: /mnt/homes/%u
      SMBSHARE_ENTRY_2_homes: yes

    volumes:
      - ./data:/mnt/data
      - ./homes:/mnt/homes
```

## LDAP Integration Notes

The container expects:

* RFC2307-style attributes
* `uidNumber`
* `gidNumber`
* Samba SID attributes for Samba authentication
* NTLM Passwordhash

## AI Usage

LLMs were used selectively for:

* syntax references
* shell portability questions
* workflow scaffolding
* documentation refinement

The project was intentionally not developed through vibe coding tools or AI-driven code generation.

The goal of the project is to fully understand the involved LDAP, Samba, NSS and identity-management mechanisms.

## Inspiration

Special thanks to:

## ServerContainers

The following project served as major inspiration:
[https://github.com/ServerContainers/samba](https://github.com/ServerContainers/samba)

This container packs everything into one optimized container.
I used it over the last years with local users.

The build quality is top and I would recommend this container to everyone who want to setup a smb fileserver with docker!

* container structure
* Samba runtime handling
* operational simplicity

## Future Plans

Planned improvements:

* further ci automation
* image hardening and optimizing
* reduced package dependecies

## Debugging

You can set the following ENVs do enable debug:

* SMBD_LOG_LEVEL
* NMBD_LOG_LEVEL
* NSLCD_DEBUG
* AVAHI_DEBUG
* WSDD2_DEBUG_LEVEL
