#!/usr/bin/env bash

# Copyright (c) 2019 Anton Semjonov
# Licensed under the MIT License

# Create scheduled zfs snapshots and purge old snapshots
# following simple x-in-timeframe retention policies.

# generate a list of prefixed properties
#  - ansemjo:autosnap (yes/no): perform automatic snapshots on this dataset
#  - ansemjo:autosnap:keep_* (int): configure retention policies of old snapshots
props() { echo ansemjo:autosnap{,:keep_{minimum,minutes,hours,days,weeks,months,years}} | tr ' ' ','; }
listheader() { printf 'name\tautosnap\tminimum\tminutes\thours\tdays\tweeks\tmonths\tyears\n'; }

# get a recursive list of datasets
list() { zfs list -Hp -r -t filesystem,volume -s name -o name,$(props) "$@"; }

# get a list of applicable snapshots per dataset
snaplist() { zfs list -Hp -d1 -t snapshot -o name,creation "$1" | grep "$1@autosnap:" ; }

# apply retention policies from properties or use defaults
retention() {
  given=$1; default=$2;
  name=$3; policy=$4;
  case "$given" in
    -) echo "$default" ;;
    ''|*[!0-9]*) echo "invalid ansemjo:autosnap:keep_$policy on $name: $given" >&2; echo "$default" ;;
    *) echo "$given" ;;
  esac
}

# apply autosnap defaults to dataset property list
applydefaults() {
  while IFS=$'\t' read name autosnap minimum minutes hours days weeks months years; do

    # decide if we should operate on this dataset, undefined or an explicit 'yes' mean yes
    if [[ $autosnap = - ]] || [[ $autosnap = yes ]]; then
      autosnap=yes
    else
      autosnap=no
    fi

    # apply default retention policies
    minimum=$(retention "$minimum"  3 "$name" minimum)
    minutes=$(retention "$minutes"  4 "$name" minutes)
      hours=$(retention "$hours"   24 "$name" hours)
       days=$(retention "$days"     7 "$name" days)
      weeks=$(retention "$weeks"    4 "$name" weeks)
     months=$(retention "$months"  12 "$name" months)
      years=$(retention "$years"   10 "$name" years)

    # echo back
    printf '%s' "$name"
    printf '\t%s' "$autosnap" "$minimum" "$minutes" "$hours" "$days" "$weeks" "$months" "$years"
    printf '\n'

  done
}


# show a nice overview for debugging
overview() { (listheader; list "$@" | applydefaults) | column -t; }

# return true if verbose
verbose() { [[ $AUTOSNAP_VERBOSE = yes ]]; }

# main routine taking snapshots and purging old ones
autosnap() {

  # check if datesieve is available
  AUTOSNAP_DATESIEVE=no
  if which datesieve >/dev/null; then
    AUTOSNAP_DATESIEVE=yes
  else
    echo "cannot purge old snapshots without https://github.com/ansemjo/datesieve" >&2
  fi

  # common execution timestamp
  timestamp=$(date --utc +%FT%T%Z)

  # iterate over datasets
  list "$@" | applydefaults | while IFS=$'\t' read name autosnap minimum minutes hours days weeks months years; do

    # check if we should operate on this dataset at all
    if [[ $autosnap = no ]]; then
      verbose && echo "skip $name" >&2
      continue
    fi

    # create new snapshot
    newsnap="$name@autosnap:$timestamp"
    zfs snapshot "$newsnap"
    verbose && echo "created snapshot: $newsnap"

    # skip purging if datesieve is unavailable
    if [[ $AUTOSNAP_DATESIEVE = no ]]; then
      continue
    fi

    # sieve old snapshots and purge
    snaplist "$name" | datesieve --sort \
      --resub '.*\t' '' --strptime '%s' \
      --minimum "$minimum" \
      --minutes "$minutes" \
      --hours "$hours" \
      --days "$days" \
      --weeks "$weeks" \
      --months "$months" \
      --years "$years" \
      | while IFS=$'\t' read snapshot epoch; do
        zfs destroy "$snapshot"
        verbose && echo "destroyed $snapshot"
      done

  done

}

usage() {
  printf '%s\n' >&2 \
    "usage: $0 [-v] [-l] [dataset [...]]" \
    "  -v  be verbose" \
    "  -l  print overview"
  exit 1
}

# ----------------------------------

cmd=autosnap
while getopts ':vl' opt; do
  case $opt in
    v) AUTOSNAP_VERBOSE=yes ;;
    l) cmd=overview ;;
    \?) usage ;;
  esac
done
shift $((OPTIND -1))
$cmd "$@"
exit 0
