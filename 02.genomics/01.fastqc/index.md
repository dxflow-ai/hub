---
title: FastQC
description: Quality control tool for high throughput sequencing data
navigation:
    icon: i-diphyx:fastqc
---

FastQC is a quality control tool for high throughput sequence data. It runs a modular set of analyses to flag problems before downstream analysis. In non-interactive mode it processes all specified files and produces an HTML report for each.

**Key features:**

- Import data from BAM, SAM or FastQ files
- Summary graphs and tables of quality control metrics
- Export reports in HTML format

## Configuration

```yaml
name: fastqc
tags:
    - genomics
steps:
    - name: job
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/fastqc:latest
      volumes:
          - name: input
            host: ./input
            container: /data/input
            mode: ro
          - name: output
            host: ./output
            container: /data/output
      env:
          - INPUT=/data/input/*.fastq.gz
          - THREADS=4
          - EXTRA=
      resources:
          cpu: "4"
          memory: 4G
```

```ini
[volume]
job.input = ./input
job.output = ./output

[env]
job.INPUT = /data/input/*.fastq.gz
job.THREADS = 4
job.EXTRA =

[resource]
job.cpu = 4
job.memory = 4G
```

```json
{
    "arch": ["amd64"],
    "version": "0.12.1",
    "minimum": {
        "cpu": 2,
        "memory": "2G",
        "storage": "10G"
    }
}
```

## Usage

### 1. Prepare data

Upload your FASTQ files:

```bash
# Create input directory
mkdir -p input output

# Upload your sequencing files
dxflow artifact upload /local/sample_R1.fastq.gz input/
dxflow artifact upload /local/sample_R2.fastq.gz input/
```

### 2. Deploy

```bash
# Deploy FastQC workflow
dxflow workflow create --identity fastqc-analysis fastqc.yml
```

### 3. Start (with optional tuning)

The step reads three env vars: `INPUT` (the input glob — point it at `.fastq.gz`, `.fastq`, `.bam`, or `.sam`), `THREADS` (how many files FastQC processes in parallel — set `1` for serial), and `EXTRA` (any additional `fastqc` flags from the [Options](#options) tables, e.g. `--extract`, `--format bam`, `--adapters …`). Tune them per run with `--override` — no need to edit the workflow:

```bash
# Start with defaults (all *.fastq.gz, THREADS=4, no extra flags)
dxflow workflow start fastqc-analysis

# Or override at start — e.g. process BAM files with extra flags
dxflow workflow start fastqc-analysis \
    --override env.job.INPUT=/data/input/*.bam \
    --override env.job.THREADS=8 \
    --override env.job.EXTRA=--extract
```

### 4. Monitor

```bash
# View logs
dxflow workflow logs fastqc-analysis

# Check status
dxflow workflow list
```

### 5. Retrieve results

```bash
# Download HTML reports
dxflow artifact download output/ /local/fastqc-results/
```

## Output files

One pair per input file:

- **`*_fastqc.html`** - HTML report with all graphs and tables
- **`*_fastqc.zip`** - ZIP archive of the detailed data files, including `summary.txt` (pass/warn/fail per module) and `fastqc_data.txt` (raw data); pass `--extract` to also unpack these to disk

## Quality metrics

### Basic Statistics

- File name, type, encoding
- Total sequences, filtered sequences
- Sequence length, %GC content

### Per Base Sequence Quality

- Quality score distribution across all bases; identifies low quality regions
- **PASS**: Median quality ≥ 25
- **WARN**: Lower quartile < 10 or median < 25
- **FAIL**: Lower quartile < 5 or median < 20

### Per Sequence Quality Scores

- Distribution of quality scores across all sequences
- **PASS**: Most sequences have quality > 27
- **WARN**: Peak quality < 27
- **FAIL**: Peak quality < 20

### Sequence Duplication Levels

- Degree of duplication in the library; high duplication may indicate PCR amplification issues

### Adapter Content

- Presence of adapter sequences; important for trimming decisions

## Interpreting results

### Good quality data

- Per base quality scores mostly in green zone (>28)
- Even GC content distribution
- Low duplication levels
- No adapter contamination

### Issues to watch for

- **Declining quality** at 3' end → Consider trimming
- **Unusual GC content** → Possible contamination
- **High duplication** → Library complexity issues
- **Adapter content** → Trimming required
- **Overrepresented sequences** → Possible contamination

## Next steps

1. **If quality is good**: Proceed to alignment/assembly
2. **If trimming needed**: Use Trimmomatic or fastp
3. **If contamination found**: Filter/remove contaminant sequences
4. **If adapter present**: Perform adapter trimming

## Options

### Basic options

| Option        | Description                 | Default           |
| ------------- | --------------------------- | ----------------- |
| `--threads`   | Files processed in parallel | 1                 |
| `--outdir`    | Output directory            | Current directory |
| `--extract`   | Extract ZIP files           | false             |
| `--noextract` | Do not extract ZIP files    | false             |

### Advanced options

| Option           | Description                         |
| ---------------- | ----------------------------------- |
| `--casava`       | Files from Casava pipeline          |
| `--nofilter`     | Do not filter sequences             |
| `--format`       | Input file format (fastq, bam, sam) |
| `--contaminants` | Custom contaminants file            |
| `--adapters`     | Custom adapters file                |
| `--limits`       | Custom limits file                  |

## References

- **Documentation**: [FastQC Documentation](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
- **Source Code**: [GitHub Repository](https://github.com/s-andrews/FastQC)
- **Tutorial**: [FastQC Tutorial](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/)
- **Video Guide**: [FastQC Usage Guide](https://www.youtube.com/watch?v=bz93ReOv87Y)

If you use FastQC in your research, please cite:

```
Andrews, S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data.
Available online at: http://www.bioinformatics.babraham.ac.uk/projects/fastqc/
```
