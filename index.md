---
title: dxflow Hub
description: Curated catalog of production-ready workflows for scientific computing, data science, and engineering applications
---

The dxflow Hub is a curated catalog of production-ready workflows. Each is a Docker Compose definition you deploy on dxflow infrastructure with a single command — from the CLI or the web console.

## Categories

::card-group
  ::card{title="Genomics" to="/hub/genomics" icon="i-hugeicons:dna-01"}
  **DNA & RNA analysis** — quality control, genome assembly, RNA-Seq, variant calling.

  Examples: FastQC, GATK, STAR, Salmon
  ::

  ::card{title="Molecular" to="/hub/molecular" icon="i-hugeicons:atom-01"}
  **Molecular simulations** — protein dynamics, drug interactions, material properties.

  Examples: GROMACS, Amber, LAMMPS, NAMD
  ::

  ::card{title="Structural" to="/hub/structural" icon="i-hugeicons:cube"}
  **3D structure analysis** — cryo-EM processing, structure prediction, modeling.

  Examples: Scipion, RELION, AlphaFold, PyMOL
  ::

  ::card{title="Data Science" to="/hub/data-science" icon="i-hugeicons:analytics-01"}
  **Analysis & development** — interactive computing, visualization, ML.

  Examples: Jupyter Lab, RStudio, VS Code Server
  ::

  ::card{title="Fluid Flow" to="/hub/fluid-flow" icon="i-hugeicons:chart-column"}
  **Computational fluid dynamics** — aerodynamics, heat transfer, multiphase flow.

  Examples: OpenFOAM, SU2, ParaView
  ::
::

## Deploy a workflow

```bash
# Browse workflows at https://dxflow.ai/hub, then:
dxflow workflow create --identity my-workflow <workflow>.yml
dxflow workflow start my-workflow
dxflow workflow logs --live my-workflow
```

Each workflow page includes its Docker Compose definition, configuration, usage examples, and system requirements. For the full deployment guide, see [How it works](/hub/getting-started/how).

## Contribute

Have a workflow others would find useful? Add it as a Markdown entry in the matching category and open a pull request to [dxflow-ai/hub](https://github.com/dxflow-ai/hub), following the structure of existing entries. Report problems or request workflows in the [community issue tracker](https://github.com/dxflow-ai/community/issues).
