#!/bin/bash
#~~~~~~~~~~
# Downloads the pinned Planetiler release's planetiler.jar (the OpenMapTiles profile built in),
# checks it against SHA256.txt, packages it as the simply-cpp-planetiler .deb (Architecture: all)
# with a /usr/bin/planetiler wrapper, and publishes it into the apt repo for resolute (SC_DISTS
# overrides). deploy.sh defaults to build-noble; the repo is shared.
#
# Run this in the directory deploy.sh synced it to (/var/www/build/sc-planetiler).

set -euo pipefail

version=$(tr -d ' \t\n' < VERSION.txt)
checksum=$(tr -d ' \t\n' < SHA256.txt)
url="https://github.com/onthegomap/planetiler/releases/download/v${version}/planetiler.jar"
package="simply-cpp-planetiler"
# A packaging revision (REVISION.txt) when the same upstream version is packaged again:
# 0.10.2-1 sorts after 0.10.2.
revision=$( [ -f REVISION.txt ] && tr -d ' \t\n' < REVISION.txt || true)
package_version="${version}${revision:+-$revision}"
deb_file="${package}_${package_version}_all.deb"

mkdir -p work
jar="work/planetiler-${version}.jar"
if [ ! -f "$jar" ]; then
    echo "Downloading $url"
    wget -q -O "$jar.part" "$url"
    mv "$jar.part" "$jar"
fi
# The release as published, or nothing: SHA256.txt is the jar's checksum from the release's own
# planetiler.jar.sha256, checked when VERSION.txt was set.
if ! echo "$checksum  $jar" | sha256sum -c --quiet -; then
    echo "planetiler.jar doesn't match SHA256.txt: not packaged" >&2
    rm -f "$jar"
    exit 1
fi

rm -rf pkg work/notices
mkdir -p pkg/DEBIAN pkg/usr/bin pkg/usr/share/planetiler "pkg/usr/share/doc/$package"
install -m 644 "$jar" pkg/usr/share/planetiler/planetiler.jar
cat > pkg/usr/bin/planetiler <<'WRAPPER'
#!/bin/sh
# Planetiler (simply-cpp-planetiler): PLANETILER_XMX sets the Java heap (default 16g).
exec java -Xmx${PLANETILER_XMX:-16g} -jar /usr/share/planetiler/planetiler.jar "$@"
WRAPPER
chmod 755 pkg/usr/bin/planetiler

# Java 21 or later: resolute's JREs provide java-runtime-headless (= <version>); openjdk-25 is its default.
cat > pkg/DEBIAN/control <<CONTROL
Package: $package
Version: $package_version
Architecture: all
Depends: openjdk-25-jre-headless | java-runtime-headless (>= 21)
Section: utils
Priority: optional
Maintainer: Roelof Rossouw
Homepage: https://github.com/onthegomap/planetiler
Description: Planetiler, a vector tile generator for OpenStreetMap data, packaged for apt
 Planetiler $version's official planetiler.jar (the OpenMapTiles profile built in),
 installed as /usr/share/planetiler/planetiler.jar with a /usr/bin/planetiler
 wrapper, so it can be installed like any other package. It turns an OSM extract
 into MBTiles or PMTiles: planetiler --osm-path=... --output=out.pmtiles.
 PLANETILER_XMX sets the Java heap (default 16g).
CONTROL

# copyright: Planetiler's licence and NOTICE.md (what it bundles, under which licences), both from
# the jar itself; every licence/notice file in the jar goes alongside in notices/.
python3 -I scripts/extract-notices.py "$jar" work/notices
doc="pkg/usr/share/doc/$package"
{
    echo "$package packages Planetiler $version (https://github.com/onthegomap/planetiler),"
    echo "licensed under Apache-2.0, unmodified. It bundles libraries under their own licences:"
    echo "see NOTICE.md below, and notices/ in this folder for their licence and notice files."
    echo "The packaging scripts (https://github.com/roelofrossouw/simply-cpp-planetiler) are Apache-2.0."
    echo
    echo "----- Planetiler: NOTICE.md -----"
    cat work/notices/NOTICE.md
    echo
    echo "----- Planetiler: LICENSE -----"
    cat work/notices/LICENSE
} > "$doc/copyright"
rm -f work/notices/NOTICE.md work/notices/LICENSE
cp -r work/notices "$doc/notices"
find "$doc" -type d -exec chmod 755 {} + && find "$doc" -type f -exec chmod 644 {} +

# The jar runs, where this server has a Java 21+ (the build servers needn't).
if java -version 2>&1 | grep -qE 'version "(2[1-9]|[3-9][0-9])'; then
    PLANETILER_XMX=1g pkg/usr/bin/planetiler --help >/dev/null 2>&1 || { echo "planetiler --help failed" >&2; exit 1; }
    echo "planetiler --help runs"
else
    echo "No Java 21+ here: planetiler --help not tried"
fi

dpkg-deb --build --root-owner-group pkg "$deb_file"

pushd /var/www/build/repo >/dev/null
export GNUPGHOME=/var/www/build/signing
# resolute only (renderd2 runs resolute); SC_DISTS="noble resolute" publishes elsewhere on demand.
for dist in ${SC_DISTS:-resolute}; do
    if reprepro list "$dist" | grep -q "$package .*$package_version"; then
        echo "$dist: $package $package_version already published"
    else
        echo "$dist: publishing $package $package_version"
        reprepro remove "$dist" "$package" || true
        reprepro includedeb "$dist" "/var/www/build/sc-planetiler/$deb_file"
    fi
done
popd >/dev/null

echo "Done."
