---
title: SAMtools
description: Read, write, and manipulate SAM, BAM, and CRAM alignment files
navigation:
    icon: i-diphyx:samtools
---

SAMtools provides utilities for sorting, indexing, filtering, and inspecting sequence alignments in the SAM/BAM/CRAM formats. In this workflow it runs a common step non-interactively: it sorts the input alignment, indexes it, and writes alignment statistics.

**Key features:**

- Convert between SAM, BAM, and CRAM
- Sort and index alignments for fast random access
- Summarize alignments with `flagstat` and `stats`

## Configuration

```yaml
name: samtools
tags:
    - genomics
steps:
    - name: job
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/samtools:latest
      volumes:
          - name: input
            host: ./input
            container: /data/input
            mode: ro
          - name: output
            host: ./output
            container: /data/output
      env:
          - INPUT=/data/input/sample.sam
          - THREADS=4
      resources:
          cpu: "4"
          memory: 4G
```

```ini
[volume]
job.input = ./input
job.output = ./output

[env]
job.INPUT = /data/input/sample.sam
job.THREADS = 4

[resource]
job.cpu = 4
job.memory = 4G
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/samtools:latest",
    "version": "1.19",
    "minimum": {
        "cpu": 2,
        "memory": "2G",
        "storage": "10G"
    }
}
```

## Usage

### 1. Prepare data

Upload an alignment file (SAM, BAM, or CRAM):

```bash
# Create input/output directories
mkdir -p input output

# Upload your alignment
dxflow artifact upload /local/sample.bam input/
```

### 2. Deploy

```bash
dxflow workflow create --identity samtools samtools.yml
```

### 3. Start (with optional tuning)

The step reads `INPUT` (the alignment to process) and `THREADS` (sort/compression threads). Override them per run:

```bash
# Start with defaults
dxflow workflow start samtools

# Or point at a BAM with more threads
dxflow workflow start samtools \
    --override env.job.INPUT=/data/input/sample.bam \
    --override env.job.THREADS=8
```

### 4. Retrieve results

```bash
dxflow artifact download output/ /local/samtools-results/
```

## Output files

- **`sorted.bam`** - the input coordinate-sorted
- **`sorted.bam.bai`** - the BAM index
- **`flagstat.txt`** - alignment counts (total, mapped, properly paired, duplicates)

## Notes

- `INPUT` accepts SAM, BAM, or CRAM — samtools detects the format automatically.
- For custom pipelines (`view`, `merge`, `mpileup`, `depth`, …), run the container interactively or supply your own script; the default step covers the common sort → index → summarize path.

## References

- **Website**: [Samtools](http://www.htslib.org/)
- **Documentation**: [Samtools Manual](http://www.htslib.org/doc/samtools.html)
- **Source**: [samtools/samtools](https://github.com/samtools/samtools)
