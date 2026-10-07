# phpbb

The container image for forum.catram.org, published as `ghcr.io/catram/phpbb`.
It is deployed by
[ansible-playbooks](https://github.com/Catram/ansible-playbooks) as a rootless
Podman Quadlet behind nginx on the host.

## What is in the image

- The current phpBB 3.3 release from download.phpbb.com, checked against its
  published SHA-256, without the `install/` folder.
- The extensions, styles and language packs in `extensions.tsv`,
  `styles.tsv` and `languages.tsv`, downloaded from phpBB's Customisation
  Database at build time by `install.sh`, each pinned to a version and checked
  against its SHA-256. phpbb.com sometimes turns away automated downloads; a
  build that hits this fails on the checksum and can simply be run again.
- `overlay/`: anything that is not on the Customisation Database, laid out as
  in the forum's root (`ext/<vendor>/<name>`, `styles/<name>`,
  `language/<code>`) and copied over the release.
- PHP 8.3 with Apache, configured by `apache.conf` and `php.ini`. phpBB's own
  `.htaccess` files are honoured.
- `config.php`, which reads everything from the environment.

## Running it

The image serves plain HTTP on port 80. It needs:

| Variable | Meaning |
|---|---|
| `PHPBB_DB_HOST` | Database host; defaults to `mariadb` |
| `PHPBB_DB_NAME`, `PHPBB_DB_USER`, `PHPBB_DB_PASSWORD` | Database credentials |
| `PHPBB_TABLE_PREFIX` | Table prefix; defaults to `phpbb_` |

and these mounts, owned by the container's `www-data` (UID 33):

| Path | Contents |
|---|---|
| `/var/www/html/files` | Attachments |
| `/var/www/html/store` | Backups and other stored files |
| `/var/www/html/images/avatars/upload` | Uploaded avatars |
| `/var/www/html/cache` | Cache; a tmpfs is best, so each start begins empty |

After a new release is deployed, migrate the database once:

```sh
php /var/www/html/bin/phpbbcli.php db:migrate
```

## Extensions, styles and languages

Each list is tab-separated, with a header row: `name`, `version`, `url`,
`sha256` and `note`. What `name` is, and what the zip must hold, depends on
the list:

| List | `name` | The zip holds | Installed as |
|---|---|---|---|
| `extensions.tsv` | `<vendor>/<name>` | `<vendor>/<name>/composer.json` | `ext/<vendor>/<name>/` |
| `styles.tsv` | the style's folder | `<name>/style.cfg` | `styles/<name>/` |
| `languages.tsv` | the language code, e.g. `zh_cmn_hans` | one folder with `language/<code>/iso.txt` | that folder copied over the root, so the pack's translations for styles and bundled extensions land too |

Not listed, because they come with phpBB: the `prosilver` style, British
English (`en`), and the `phpbb/viglink` extension.

To add or update an entry, take the download link of the revision from its
page on the [Customisation Database](https://www.phpbb.com/customise/db/),
without the `?sid=...` part, and its SHA-256:

```sh
curl -fsSL <url> | sha256sum
```

After a new version is deployed, `db:migrate` runs its migrations too.

## Building

Every push to `main` builds and pushes the image on a GitHub-hosted runner,
and so does a weekly scheduled run, which picks up a new phpBB release. Each
build is tagged `<version>-<run number>`, e.g. `3.3.19-12`; deployments pin
one of these tags. The `3.3` tag always points to the latest build.
