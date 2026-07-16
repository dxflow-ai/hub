#!/bin/sh

set -eu

pangolin "$INPUT" --outdir /data/output --threads "$THREADS" $EXTRA
