---
title: Pangolin
description: SARS-CoV-2 lineage assignment using the Pango nomenclature
navigation:
    icon: i-diphyx:pangolin
---

Pangolin assigns SARS-CoV-2 genome sequences to Pango lineages for genomic surveillance. Given one or more consensus genomes in a FASTA file, it aligns them, runs the assignment pipeline, and writes a lineage report.

**Key features:**

- Assign SARS-CoV-2 sequences to Pango lineages
- Bundled lineage and designation data (pdata)
- CSV report with lineage, conflict, and QC status per sequence

## Configuration

```yaml
name: pangolin
tags:
    - genomics
steps:
    - name: job
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/pangolin:latest
      volumes:
          - name: input
            host: ./input
            container: /data/input
            mode: ro
          - name: output
            host: ./output
            container: /data/output
      env:
          - INPUT=/data/input/sequences.fasta
          - THREADS=4
          - EXTRA=
      resources:
          cpu: "4"
          memory: 8G
```

```ini
[volume]
job.input = ./input
job.output = ./output

[env]
job.INPUT = /data/input/sequences.fasta
job.THREADS = 4
job.EXTRA =

[resource]
job.cpu = 4
job.memory = 8G
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/pangolin:latest",
    "version": "4.3.1",
    "minimum": {
        "cpu": 2,
        "memory": "4G",
        "storage": "10G"
    }
}
```

## Usage

### 1. Prepare data

Upload a FASTA file of one or more SARS-CoV-2 consensus genomes:

```bash
# Create input/output directories
mkdir -p input output

# Upload your sequences
dxflow artifact upload /local/sequences.fasta input/
```

### 2. Deploy

```bash
dxflow workflow create --identity pangolin pangolin.yml
```

### 3. Start (with optional tuning)

The step reads `INPUT` (the query FASTA), `THREADS`, and `EXTRA` (extra `pangolin` flags, e.g. `--analysis-mode fast`). Override them per run:

```bash
# Start with defaults
dxflow workflow start pangolin

# Or point at another file and pass extra flags
dxflow workflow start pangolin \
    --override env.job.INPUT=/data/input/genomes.fasta \
    --override env.job.EXTRA=--analysis-mode\ usher
```

### 4. Retrieve results

```bash
dxflow artifact download output/ /local/pangolin-results/
```

## Output files

- **`lineage_report.csv`** - one row per input sequence: `taxon`, `lineage`, `conflict`, `scorpio_call`, `qc_status`, and the tool/data versions used

## Notes

- Input should be near-complete SARS-CoV-2 genomes; short or low-coverage sequences are still reported but marked `fail` in `qc_status`.
- The image bundles the lineage data (`pdata`), so assignment runs offline — no network download is needed at runtime.

## References

- **Source**: [cov-lineages/pangolin](https://github.com/cov-lineages/pangolin)
- **Documentation**: [Pangolin Docs](https://cov-lineages.github.io/pangolin/)
- **Lineages**: [cov-lineages.org](https://cov-lineages.org/)
