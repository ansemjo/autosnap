#!/usr/bin/env bash

# generate a list of prefixed properties
props() { echo ansemjo:autosnap{,:keep_{minimum,minutes,hours,days,weeks,months,years}} | tr ' ' ','; }

# get a recursive list of datasets
list() { zfs list -Hp -r -t filesystem,volume -s name -o name,$(props) "$@"; }
listheader() { printf 'name\tautosnap\tminimum\tminutes\thours\tdays\tweeks\tmonths\tyears\n'; }

# get a list of applicable snapshots
snaplist() { zfs list -Hp -d1 -t snapshot -o name,creation "$1" | grep "$1@autosnap:" ; }

# datesieve alias to apply needed resub
sieve() { datesieve --resub '.*\t' '' --strptime '%s' --sort "$@"; }

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


# ---------------------------------------

if [[ -z $1 ]]; then
  echo "usage: $0 pool/dataset [...]" >&2
  exit 1
fi

timestamp=$(date --utc +%FT%T%Z)

(listheader; list "$@") | column -t
list "$@" | while IFS=$'\t' read name autosnap minimum minutes hours days weeks months years; do

  # check if we should operate on this at all
  if [[ $autosnap = no ]]; then
    echo "skip $name" >&2
    continue
  fi
  
  # apply default retention policies
  minimum=$(retention "$minimum"  3 "$name" minimum)
  minutes=$(retention "$minutes"  1 "$name" minutes)
    hours=$(retention "$hours"   24 "$name" hours)
     days=$(retention "$days"     7 "$name" days)
    weeks=$(retention "$weeks"    4 "$name" weeks)
   months=$(retention "$months"  12 "$name" months)
    years=$(retention "$years"   10 "$name" years)
  
  zfs snapshot "$name@autosnap:$timestamp"
  echo "created $name@autosnap:$timestamp"

  snaplist "$name" | sieve \
    --minimum "$minimum" \
    --minutes "$minutes" \
    --hours "$hours" \
    --days "$days" \
    --weeks "$weeks" \
    --months "$months" \
    --years "$years" \
    | while IFS=$'\t' read snapshot epoch; do
      zfs destroy "$snapshot"
      echo "destroyed $snapshot"
    done

done
