#!/bin/sh

set -eu

mkdir -p /data/output

# Sort, index, and summarize the input alignment
samtools sort "$INPUT" -@ "$THREADS" -o /data/output/sorted.bam
samtools index /data/output/sorted.bam
samtools flagstat /data/output/sorted.bam > /data/output/flagstat.txt
