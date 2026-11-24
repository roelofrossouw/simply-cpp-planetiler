# simply-cpp-planetiler

[Planetiler](https://github.com/onthegomap/planetiler) (turns OpenStreetMap data into vector tiles,
MBTiles or PMTiles), its official `planetiler.jar` with the OpenMapTiles profile built in, packaged
as an apt package. There's no source of ours here beyond the packaging: the jar is the release
Planetiler publishes, downloaded and checked against `SHA256.txt`.

## Install

```bash
curl -fsSL https://apt.roelof.co.za/setup.sh | bash
sudo apt -y install simply-cpp-planetiler
planetiler --help
```

It installs `/usr/share/planetiler/planetiler.jar`, a `/usr/bin/planetiler` wrapper
(`java -Xmx${PLANETILER_XMX:-16g} -jar ...`) and the licences: Planetiler's, its NOTICE.md and the
licence/notice files of what the jar bundles. It needs Java 21 or later
(`openjdk-25-jre-headless | java-runtime-headless (>= 21)`). Published for resolute only
(`SC_DISTS="noble resolute" scripts/deploy.sh` on demand).

## The version

`VERSION.txt` is the Planetiler release packaged (tag `v<version>`), `SHA256.txt` the jar's
SHA-256 as the release's own `planetiler.jar.sha256` gives it.

## Publishing a new version

Set `VERSION.txt` and `SHA256.txt`, commit, then `scripts/deploy.sh` (or the suite's
`scripts/publish.sh --only planetiler`). The same version packaged again takes a `REVISION.txt`.

## Licence

The packaging scripts are Apache-2.0 (`LICENSE`); Planetiler is Apache-2.0, with its bundled
libraries' licences in `/usr/share/doc/simply-cpp-planetiler/`.
