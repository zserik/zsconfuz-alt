#!/bin/bash

# project: zsconfuz-alt
# a script which converts a subset of zsconfuz into a ninja file
# USAGE: zscfz2ninja.sh < ZSconfuz.txt > zscfz.ninja
# (C) 2019 Erik Zscheile
# License: ISC

OUTPUT_DEF="zsconfuz_results.sh" # keep this line in sync with src/dflout.h
IN_PREAMBLE=true

print_ninja_preamble() {
  # ninja preamble, without definition of results_file
cat <<EOF
# This file is generated by zscfz2ninja.sh($*)

results_file = ${OUTPUT_DEF}
tmpdir = ./.zscfzFiles

rule runrawcmd
  command = \$COMMAND && touch \$out
  description = \$DESC

rule runcmd
  command = zscfz-runcmd \$results_file \$COMMAND && touch \$out
  description = \$COMMAND

rule section
  command = zscfz-ppsec \$NAME && touch \$out
  description = : \$NAME

build \$tmpdir/L0 \$results_file: runrawcmd
  COMMAND = rm -f \$results_file && touch \$results_file
  DESC = prepare \$results_file

EOF
}

CNT_BEFSEC=0
CNT_AFTSEC=1

print_steplist() {
  set -- $(seq $CNT_BEFSEC $(expr $CNT_AFTSEC - 1))
  # if there are commands in the section, we don't need to reference the section itself
  [ $# -gt 1 ] && shift
  for i; do echo -n " \$tmpdir/L$i"; done
}

# print_command sec|cmd ARGS...
print_command() {
  local ORIG_BEFSEC="$CNT_BEFSEC"
  echo -n "build \$tmpdir/L$CNT_AFTSEC: "
  case "$1" in
    (sec)
      echo -n section
      print_steplist
      CNT_BEFSEC="$CNT_AFTSEC"
      echo
      echo "  NAME = $2"
      ;;
    (cmd)
      echo -n runcmd
      [ "$ORIG_BEFSEC" -ne 0 ] && echo -n " \$tmpdir/L$ORIG_BEFSEC"
      shift
      echo " $(which "$1")"
      echo "  COMMAND = $@"
      ;;
  esac
  echo
  let CNT_AFTSEC++
}

# sed fixes the escape seqs
sed -e 's/\\/\\\\/g' | (
  while read CMD ARGS; do
    [ -z "$CMD" ] && continue

    case "$CMD" in
      ('output')
        # shell results file def
        OUTPUT_DEF="$ARGS"
        ;;

      ('#')
        echo '#' "$ARGS"
        ;;

      (':')
        # section definition
        if $IN_PREAMBLE; then
          print_ninja_preamble "$@"
          IN_PREAMBLE=false
        fi
        print_command sec "$ARGS"
        ;;

      (*)
        # command
        if $IN_PREAMBLE; then
          echo "zscfz2ninja.sh: ERROR: command in preamble is unsupported" 1>&2
          exit 1
        fi
        print_command cmd "$CMD" "$ARGS"
        ;;
    esac
  done

# hacky part to ensure we have an up-to-date steplist
cat <<EOF
build all: phony$(print_steplist)
default all
EOF
)
