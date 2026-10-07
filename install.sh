#!/bin/sh
# Installs phpBB and the pinned add-ons into the web root. Run by the
# Containerfile, which provides wget and unzip.
#
#   install.sh <phpBB version> <web root>
#
# Every download is checked against a SHA-256: phpBB against the one
# published next to it, the add-ons against the ones pinned in the TSV files
# next to this script (extensions.tsv, styles.tsv, languages.tsv).
#
# phpbb.com is behind Cloudflare, which challenges a user agent that looks
# like a bot, such as one with a URL in it. wget's own gets through.
set -eu

version=$1
root=${2:?web root}
here=$(dirname "$0")
tab=$(printf '\t')
work=$(mktemp -d)

# fetch URL SHA256: download URL, check it, and unpack it into $work/unpacked.
fetch() {
	wget -nv -O "$work/download.zip" "$1"
	echo "$2  $work/download.zip" | sha256sum -c -
	rm -rf "$work/unpacked"
	unzip -q "$work/download.zip" -d "$work/unpacked"
}

# rows FILE: the rows of a TSV file, without its header and blank lines.
rows() {
	tail -n +2 "$1" | grep -v '^[[:space:]]*$' || true
}

# phpBB itself, without the installer.
base="https://download.phpbb.com/pub/release/${version%.*}/$version"
sha256=$(wget -nv -O - "$base/phpBB-$version.zip.sha256" | cut -d' ' -f1)
test -n "$sha256"
fetch "$base/phpBB-$version.zip" "$sha256"
rm -rf "$root"
mv "$work/unpacked/phpBB3" "$root"
rm -rf "$root/install"

# Extensions: the zip holds <vendor>/<name>/.
rows "$here/extensions.tsv" | while IFS=$tab read -r name pinned url sha256 _; do
	echo "Extension $name $pinned"
	fetch "$url" "$sha256"
	test -f "$work/unpacked/$name/composer.json"
	mkdir -p "$root/ext/${name%/*}"
	mv "$work/unpacked/$name" "$root/ext/$name"
done

# Styles: the zip holds <name>/ with its style.cfg.
rows "$here/styles.tsv" | while IFS=$tab read -r name pinned url sha256 _; do
	echo "Style $name $pinned"
	fetch "$url" "$sha256"
	test -f "$work/unpacked/$name/style.cfg"
	mv "$work/unpacked/$name" "$root/styles/$name"
done

# Languages: the zip holds one folder laid out like the forum's root, with
# language/<code>/ and the pack's translations for styles and bundled
# extensions. It is copied over the root.
rows "$here/languages.tsv" | while IFS=$tab read -r name pinned url sha256 _; do
	echo "Language $name $pinned"
	fetch "$url" "$sha256"
	set -- "$work/unpacked"/*
	test "$#" -eq 1
	test -f "$1/language/$name/iso.txt"
	cp -R "$1/." "$root/"
done

rm -rf "$work"
