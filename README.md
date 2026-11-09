# spinel-packer

Legacy vendoring compatibility and migration to the official Spinel `spin` tool.
New projects should use `spin init`, `spin add`, `spin lock`, `spin vendor` and `spin test`.

```sh
ruby spinel-packer migrate Spinelfile
spin lock
# Review spin.toml and spin.lock; replace vendor/... require paths with package entry points.
```

Migration accepts only pinned, literal `use "owner/repo", sha: "<40 hex>"` declarations.
It never executes a Spinelfile, never overwrites spin.toml, and rejects executable or
unpinned input for explicit review. It preserves Git SHAs, not the old vendor layout.

Legacy install/upgrade/lock/check remain available. New locks use spec 0.2 and
`path-kind-mode-length-v2`: paths, entry type, permissions, file boundaries, symlink
targets and hidden files contribute to the digest. Old content-only locks are rejected
on strict install: migrate, or inspect the source and regenerate with `lock`.
A lock is an integrity record, not proof that untrusted dependency code is safe.

The deprecated `pack` command expands standalone literal require_relative lines only;
missing files are errors. It is not a general Ruby parser or a replacement for compiler
load semantics. Official `spin pack` instead exports C, runtime sources and a Makefile.
These output formats are intentionally different.

The official resolver may reselect after a manifest constraint change. Do not assume
an undocumented `--frozen` option exists; review the lock and use offline vendoring
plus a clean-tree check in CI when reproducibility is required.

## Compatibility and verification

Supported baseline: Spinel `2026.10.25` (Linux) and CRuby 3.1+. CI also checks the
reference master commit `60c0273261415d2b5edd6480667a705a68addbd2`; this is a pinned
comparison, not an assertion about every future master build. Check CHANGELOG before upgrading.
No performance or binary-size claim is inherited from the May prototype.

Run `rake test`. Runtime packages additionally use `spin test`; generator repositories
use `ruby scripts/verify_runtime.rb` to compile their generated code and compare with CRuby.
See CONTRIBUTING.md. Original notes are in `docs/historical-readme-may-2026.md`.

MIT licensed. Development version; no gem or package-index release is published automatically.
