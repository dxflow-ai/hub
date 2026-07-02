#!/bin/sh

set -eu

fastqc $INPUT --outdir /data/output --threads "$THREADS" $EXTRA
