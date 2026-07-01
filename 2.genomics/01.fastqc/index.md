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
  - name: fastqc
    platform: docker
    mode: sequential
    image: ghcr.io/dxflow-ai/fastqc:latest
    command:
      - /bin/sh
      - -c
      - fastqc /data/input/*.fastq.gz --outdir /data/output --threads 4
    volumes:
      - host: ./input
        container: /data/input
        mode: ro
      - host: ./output
        container: /data/output
    resources:
      cpu: "4"
      memory: 4G
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

# Start analysis
dxflow workflow start fastqc-analysis
```

### 3. Monitor

```bash
# View logs
dxflow workflow logs fastqc-analysis

# Check status
dxflow workflow list
```

### 4. Retrieve results

```bash
# Download HTML reports
dxflow artifact download output/ /local/fastqc-results/
```

## Output files

- **`*_fastqc.html`** - HTML report with all graphs and tables
- **`*_fastqc.zip`** - ZIP archive containing detailed data files
- **`summary.txt`** - Summary of pass/warn/fail for all modules
- **`fastqc_data.txt`** - Raw data for all analyses

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

### Batch processing

```yaml
# Process all FASTQ files in parallel
command: >
  parallel -j 4 fastqc {} --outdir /data/output ::: /data/input/*.fastq.gz
```

## Next steps

1. **If quality is good**: Proceed to alignment/assembly
2. **If trimming needed**: Use Trimmomatic or fastp
3. **If contamination found**: Filter/remove contaminant sequences
4. **If adapter present**: Perform adapter trimming

## Options

### Basic options

| Option | Description | Default |
|--------|-------------|---------|
| `--threads` | Number of CPU threads | 1 |
| `--outdir` | Output directory | Current directory |
| `--extract` | Extract ZIP files | false |
| `--noextract` | Do not extract ZIP files | false |

### Advanced options

| Option | Description |
|--------|-------------|
| `--casava` | Files from Casava pipeline |
| `--nofilter` | Do not filter sequences |
| `--format` | Input file format (fastq, bam, sam) |
| `--contaminants` | Custom contaminants file |
| `--adapters` | Custom adapters file |
| `--limits` | Custom limits file |

## Requirements

**Minimum:**
- CPU: 2 cores
- RAM: 2GB
- Storage: 10GB

**Recommended:**
- CPU: 4+ cores for faster processing
- RAM: 4GB for large files
- Storage: 50GB for multiple samples

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
