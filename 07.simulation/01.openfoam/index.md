---
title: OpenFOAM
description: Open source computational fluid dynamics (CFD) software
navigation:
    icon: i-diphyx:openfoam
---

OpenFOAM (Open Field Operation and Manipulation) is a free, open-source CFD package with solvers and utilities for fluid flow, turbulence, heat transfer, and reacting flows, backed by remote compute. This image bundles OpenFOAM 10 (with ParaView); the container stays up so you can run mesh, solver, and post-processing commands against cases mounted at `/data`.

## Configuration

```yaml
name: openfoam
tags:
    - simulation
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/openfoam:latest
      command:
          - tail
          - -f
          - /dev/null
      volumes:
          - name: volume
            host: ./volume
            container: /data
      resources:
          cpu: "16"
          memory: 32G
```

```ini
[volume]
app.volume = ./volume

[resource]
app.cpu = 16
app.memory = 32G
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/openfoam:latest",
    "version": "10",
    "minimum": {
        "cpu": 8,
        "memory": "16G",
        "storage": "50G"
    }
}
```

## Usage

### 1. Deploy

```bash
dxflow workflow create --identity openfoam openfoam.yml
dxflow workflow start openfoam
```

The container stays up so you can run OpenFOAM commands against data mounted at `/data`.

### 2. Run a case

The commands below run inside the workflow container.

```bash
# Copy a tutorial case into the mounted volume
cp -r $FOAM_TUTORIALS/incompressible/icoFoam/cavity/cavity /data/cavity
cd /data/cavity

# Mesh, solve, post-process
blockMesh
icoFoam
postProcess -func 'writeCellCentres'
```

### 3. Run in parallel

```bash
decomposePar
mpirun -np 16 simpleFoam -parallel
reconstructPar
```

### 4. Retrieve results

Everything under `/data` persists — meshes, time directories, and logs are written there. Visualize with the [ParaView](/hub/visualization/paraview) image.

## Common solvers

| Solver          | Application              | Type         |
| --------------- | ------------------------ | ------------ |
| `icoFoam`       | Laminar incompressible   | Transient    |
| `simpleFoam`    | Turbulent incompressible | Steady-state |
| `pimpleFoam`    | Turbulent incompressible | Transient    |
| `interFoam`     | Two-phase flow (VOF)     | Transient    |
| `rhoSimpleFoam` | Compressible turbulent   | Steady-state |

## Case structure

```
myCase/
├── 0/          # Initial and boundary conditions (U, p, T, …)
├── constant/   # Mesh (polyMesh/) and physical properties
└── system/     # controlDict, fvSchemes, fvSolution
```

## Notes

- The OpenFOAM environment is sourced automatically, so `blockMesh`, `icoFoam`, `snappyHexMesh`, etc. are on `PATH`.
- For parallel runs, `decomposePar` splits the case, `mpirun -np N <solver> -parallel` runs it, and `reconstructPar` merges the result.

## References

- **Website**: [OpenFOAM.org](https://openfoam.org/)
- **Documentation**: [User Guide](https://doc.cfd.direct/openfoam/user-guide-v10/index)
- **Tutorials**: [OpenFOAM Tutorials](https://openfoam.org/tutorials/)
