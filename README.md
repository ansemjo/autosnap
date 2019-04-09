# autosnap(8) -- scheduled zfs snapshots with automatic purging

## SYNOPSIS

    systemctl enable --now autosnap.timer

## DESCRIPTION

`autosnap` creates snapshots of ZFS datasets regularly and purges old snapshots based on a 
keep-x-in-timeframe retention policy. It is a simpler replacement for `zfs-auto-snapshot`.

See `zfs(8)` for details on creating and destroying ZFS snapshots manually.

## USAGE

When `autosnap` is installed you can use it on the commandline or enable the included systemd
timer for fully automatic operation. The systemd unit by default runs on all datasets and must
be configured through ZFS properties. Retention policies cannot be given on the commandline and
must be configured with properties in any case.

    autosnap [-l] [-v] [dataset [...]]

- __dataset__: give the datasets to operate on recursively as arguments, no arguments means "all available"

- __-l__: only show an overview of datasets and their explicitly configured retention policies, then exit

- __-v__: be verbose and print what we're doing (created/destroyed datasets)

## CONFIGURATION

Configure `autosnap` by setting properties on the ZFS datasets directly with
`zfs set ansemjo:autosnap:... pool/dataset`. Available properties are:

| property | valid values | meaning |
| -------- | ------------ | ------- |
| ansemjo:autosnap | 'yes' / 'no' | perform autosnapshots and purging on this dataset _at all_ |
| ansemjo:autosnap:keep_minimum | positive integer | keep __at least__ _x_ snapshots, regardless of age |
| ansemjo:autosnap:keep_minutes | positive integer | keep at least _x_ __minutes__ of snapshots |
| ansemjo:autosnap:keep_hours | positive integer | keep at least _x_ __hours__ of snapshots |
| ansemjo:autosnap:keep_days | positive integer | keep at least _x_ __days__ of snapshots |
| ansemjo:autosnap:keep_weeks | positive integer | keep at least _x_ __weeks__ of snapshots |
| ansemjo:autosnap:keep_months | positive integer | keep at least _x_ __months__ of snapshots |
| ansemjo:autosnap:keep_years | positive integer | keep at least _x_ __years__ of snapshots |

ZFS properties are inherited by default, so if you want to disable snapshotting for an entire subtree of datasets
simply set `ansemjo:autosnap=no` on its root. To reset a property to its inherited value use
`zfs inherit ansemjo:autosnap:... pool/dataset`.

For example setting `ansemjo:autosnap:keep_days` to 7 means that for every day one snapshot will be kept,
up to a maximum of 7 days. This does not mean that the oldest snapshot can be 8 days old, however. If you
only have snapshots every second day, you oldest snapshot according to this policy will be 14 days old.
See [ansemjo/datesieve](https://github.com/ansemjo/datesieve) for details.

By default, if no explicit policies are configured, `autosnap` will keep:

- at least 3
- 4 minutes
- 24 hours
- 7 days
- 4 weeks
- 12 months
- 10 years

## INSTALLATION

Install one of the `rpm` or `deb` packages from the Releases page.

Alternatively clone the repository or download and extract a release and use `make install` to
install the script and unit files manually.

__For automatic purging [datesieve](https://github.com/ansemjo/datesieve) is required.__ You can
install it quickly with `pip`:

    pip install git+https://github.com/ansemjo/datesieve

