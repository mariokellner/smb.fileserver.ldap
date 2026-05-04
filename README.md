# Samba Container with LDAP (mainly for LDAP MOD Authenetik)

This Container is meant to be used with LDAP Provider MOD to enable authentication from authentik instead of relaying on local users.

It uses ldapsam+nslcd(pam) to sync the accounts from authentik and uses it as source.

It can be used with any LDAP provider that support LDAP.
But my goal was that I can enable login from authentik with this image.

Currently this image is build ontop of debian:book-worm. Not the smallest one but it gave me a qickstart as im usualy don´t build such containers.

I modded the ldap provider for personal use. The code is located here:
https://github.com/mariokellner/authentik-ldap-samba-mod

## Defaults

As this Container is purely there to enable LDAP Authentication within the container it expect some defaults. All other configuration can be done by providing own configuration parameter.

## Tec Stack

The container is a multiprocess container with the following dependencies

* smbd
* nslcd
* nmbd
* avahi
* wsdd2
* supervisor (because i could get runit work on debian)

## How To Use
Todo (Mario): Write todo and describe config parameter

## Thanks goes to

### ServerContainers / Samba

This container packs everything into one optimized container.
I used it over the last years with local users.

Sadly sssd and nslcd missing from that image.
I took a lot of insperation of that container as the build quality imho. is top.

Here is the [https://github.com/ServerContainers/samba](https://github.com/ServerContainers/samba)

## AI / Vibe Coding

Im a big fan of LLMs and I use it on daily basis. Heck ibBuild Agents with it.
But as I am not a fan of vibe coding in my free time, this image development was done without any AI Tools.

Vibecoding isnt bad. But everything I develop in my free time I want to understand to the fullest. Therefore vibecoding an LDAP Container seems like a lazy shortcut thius time.
