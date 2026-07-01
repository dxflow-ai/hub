---
title: dxflow Hub
description: Curated catalog of production-ready workflows for scientific computing, data science, and engineering applications
---

The dxflow Hub is a curated catalog of production-ready workflows. Each is a dxflow workflow definition you deploy on dxflow infrastructure with a single command — from the CLI or the web console.

## Categories

::card-group
  ::card{title="Genomics" to="/hub/genomics" icon="i-hugeicons:dna-01"}
  **DNA & RNA analysis** — quality control, genome assembly, RNA-Seq, variant calling.

  Examples: FastQC, SAMtools, Pangolin
  ::

  ::card{title="Molecular" to="/hub/molecular" icon="i-hugeicons:atom-01"}
  **Molecular simulations** — protein dynamics, drug interactions, material properties.

  Examples: GROMACS, PyMOL
  ::

  ::card{title="Structural" to="/hub/structural" icon="i-hugeicons:cube"}
  **3D structure analysis** — cryo-EM processing, structure prediction, modeling.

  Examples: Scipion
  ::

  ::card{title="Analytics" to="/hub/analytics" icon="i-hugeicons:analytics-01"}
  **Interactive computing** — notebooks, statistics, ML, and local LLMs.

  Examples: Jupyter Lab, RStudio, Ollama
  ::

  ::card{title="Simulation" to="/hub/simulation" icon="i-hugeicons:chart-column"}
  **CFD & multiphysics** — aerodynamics, heat transfer, combustion.

  Examples: OpenFOAM, SU2
  ::

  ::card{title="Visualization" to="/hub/visualization" icon="i-hugeicons:chart-line-data-02"}
  **Scientific visualization** — post-processing and rendering of large datasets.

  Examples: ParaView, VisIt
  ::

  ::card{title="Development" to="/hub/development" icon="i-hugeicons:source-code"}
  **Cloud IDEs** — full development environments in your browser.

  Examples: VS Code, Coder
  ::

  ::card{title="Desktop" to="/hub/desktop" icon="i-hugeicons:computer"}
  **Remote desktops & apps** — Linux desktops, browsers, and graphics tools.

  Examples: Ubuntu, Firefox, GIMP
  ::

  ::card{title="Infrastructure" to="/hub/infrastructure" icon="i-hugeicons:server-stack-01"}
  **Cluster & scheduling** — orchestrate and scale compute workloads.

  Examples: Slurm
  ::
::

## Deploy a workflow

```bash
# Browse workflows at https://dxflow.ai/hub, then:
dxflow workflow create --identity my-workflow <workflow>.yml
dxflow workflow start my-workflow
dxflow workflow logs --live my-workflow
```

Each workflow page includes its workflow definition, configuration, usage examples, and system requirements. For the full deployment guide, see [How it works](/hub/getting-started/how).

## Contribute

Have a workflow others would find useful? Add it as a folder in the matching category — an `index.md` describing it plus a `Dockerfile` for its image — and open a pull request to [dxflow-ai/hub](https://github.com/dxflow-ai/hub), following the structure of existing entries. Report problems or request workflows in the [community issue tracker](https://github.com/dxflow-ai/community/issues).
