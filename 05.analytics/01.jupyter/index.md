---
title: Jupyter Lab
description: Interactive development environment for notebooks, code, and data
navigation:
    icon: i-diphyx:jupyter
---

JupyterLab is a web-based interactive development environment for notebooks, code, and data, supporting Python, R, and Julia with a code editor, terminal access, file browser, an extension ecosystem, and real-time collaboration.

## Configuration

```yaml
name: jupyter
tags:
  - analytics
steps:
  - name: jupyter
    platform: docker
    mode: sequential
    image: jupyter/scipy-notebook:latest
    command:
      - start-notebook.sh
      - --NotebookApp.token=your-secret-token
    env:
      - JUPYTER_ENABLE_LAB=yes
      - JUPYTER_TOKEN=your-secret-token
      - GRANT_SUDO=yes
    ports:
      - name: notebook
        host: "8888"
        container: "8888"
    volumes:
      - name: notebooks
        host: ./notebooks
        container: /home/jovyan/work
      - name: data
        host: ./data
        container: /home/jovyan/data
    resources:
      cpu: "8"
      memory: 16G
```

## Usage

### 1. Prepare data

```bash
# Create directories
mkdir -p notebooks data

# Upload data files
dxflow artifact upload /local/dataset.csv data/
```

### 2. Deploy

```bash
# Deploy Jupyter Lab
dxflow workflow create --identity jupyter jupyter.yml
dxflow workflow start jupyter

# Access Jupyter Lab
# Open browser: http://localhost:8888
# Token: your-secret-token
```

### 3. Monitor

```bash
# View live logs
dxflow workflow logs --live jupyter

# List workflows
dxflow workflow list
```

### 4. Retrieve results

```bash
# Download notebooks
dxflow artifact download notebooks/ /local/notebooks/
```

## Working with notebooks

```python
# Example Python notebook
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# Load data
data = pd.read_csv('/home/jovyan/data/dataset.csv')

# Analyze
data.describe()

# Visualize
plt.figure(figsize=(10, 6))
plt.plot(data['x'], data['y'])
plt.xlabel('X axis')
plt.ylabel('Y axis')
plt.title('Data Visualization')
plt.show()
```

## Pre-installed libraries

**Data Science Stack:**
- NumPy - Numerical computing
- Pandas - Data manipulation
- Matplotlib - Visualization
- Seaborn - Statistical plots
- SciPy - Scientific computing
- Scikit-learn - Machine learning

**Optional GPU Support:**

For ML/DL, switch to a GPU image and request a GPU on the step:

```yaml
steps:
  - name: jupyter
    image: jupyter/tensorflow-notebook:latest
    resources:
      gpu: nvidia
```

## Extensions

Popular JupyterLab extensions. Run the following commands inside the jupyter workflow container:

```bash
# Install extensions
pip install jupyterlab-git jupyterlab-lsp

# Code formatter
pip install jupyterlab_code_formatter black

# Table of contents
pip install jupyterlab-toc
```

## Requirements

**Light Workloads:**
- CPU: 4 cores
- RAM: 8GB
- Storage: 50GB

**Standard Workloads:**
- CPU: 8 cores
- RAM: 16GB+
- Storage: 100GB SSD

## References

- **Website**: [JupyterLab](https://jupyterlab.readthedocs.io/)
- **Documentation**: [JupyterLab Docs](https://jupyterlab.readthedocs.io/en/stable/)
- **Gallery**: [Notebook Gallery](https://github.com/jupyter/jupyter/wiki)
