---
title: SU2
description: Open-source CFD suite for aerodynamic analysis and optimization
navigation:
    icon: i-diphyx:su2
---

SU2 is an open-source suite for computational fluid dynamics and PDE-constrained optimization, widely used in aerodynamics and aerospace, backed by remote compute. This image bundles SU2 8.0.1 with MPI; the container stays up so you can run solver and optimization commands against cases mounted at `/data`.

## Configuration

```yaml
name: su2
tags:
    - simulation
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/su2:latest
      command:
          - tail
          - -f
          - /dev/null
      volumes:
          - name: volume
            host: ./volume
            container: /data
      resources:
          cpu: "4"
          memory: 32G
```

```ini
[volume]
app.volume = ./volume

[resource]
app.cpu = 4
app.memory = 32G
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/su2:latest",
    "version": "8.0.1",
    "minimum": {
        "cpu": 2,
        "memory": "16G",
        "storage": "50G"
    }
}
```

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity su2 su2.yml
dxflow workflow start su2
```

The container stays up so you can run SU2 commands against data mounted at `/data`.

### 2. Run a case

Put your `.cfg` config and `.su2` mesh under `/data`, then run inside the workflow container:

```bash
cd /data

# Serial run
SU2_CFD case.cfg

# Parallel run (N ranks)
mpirun -np 16 SU2_CFD case.cfg
# or the Python driver
parallel_computation.py -f case.cfg -n 16
```

### 3. Retrieve results

Everything under `/data` persists — restart files, surface/volume solutions, and history are written there. Visualize with the [ParaView](/hub/visualization/paraview) image.

## Common tools

| Tool            | Purpose                             |
| --------------- | ----------------------------------- |
| `SU2_CFD`       | Core flow solver                    |
| `SU2_DEF`       | Mesh deformation                    |
| `SU2_SOL`       | Generate solution output files      |
| `SU2_GEO`       | Geometry evaluation                 |
| `SU2_DOT`       | Gradient projection for optimization|

## Notes

- `SU2_RUN` is set and the SU2 binaries and Python drivers are on `PATH` / `PYTHONPATH`, so `SU2_CFD` and `parallel_computation.py` work out of the box.
- MPI is allowed to run as root (`OMPI_ALLOW_RUN_AS_ROOT`), so `mpirun -np N SU2_CFD` runs without extra flags.

## References

- **Website**: [SU2code](https://su2code.github.io/)
- **Documentation**: [SU2 Docs](https://su2code.github.io/docs_v7/home/)
- **Tutorials**: [SU2 Tutorials](https://su2code.github.io/tutorials/home/)
