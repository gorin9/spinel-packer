# Legacy package spec 0.2

New projects use official spin.toml/spin.lock. See README for migration.
Legacy manifests retain the Ruby Spinelfile DSL for compatibility; migration itself
only accepts pinned literal lines and never evaluates it.

Lock JSON includes spinel_pkg_spec=0.2, tree_hash_format=path-kind-mode-length-v2,
and deps. Each tree digest includes sorted relative paths, entry types, permission
bits, byte lengths and file bytes or symlink target. Hidden files are included;
.spnl-source is metadata and excluded. Strict install requires manifest names/SHAs
to match the lock and rejects old content-only locks. check detects tree drift.
