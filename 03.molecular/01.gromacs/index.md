---
title: GROMACS
description: Molecular dynamics simulation package for biomolecular systems
navigation:
    icon: i-diphyx:gromacs
---

GROMACS is a versatile, high-performance package for molecular dynamics simulations of proteins, lipids, and nucleic acids, backed by remote compute. This image is built once with **both MPI and CUDA** support: `gmx_mpi` uses an attached NVIDIA GPU when present and falls back to CPU/MPI when not — so the same image covers both modes.

## Configuration

Attach a GPU with `resources.gpu: nvidia` for CUDA acceleration, or remove it to run CPU/MPI-only.

```yaml
name: gromacs
tags:
    - molecular
steps:
    - name: app
      platform: docker
      mode: parallel
      image: ghcr.io/dxflow-ai/gromacs:latest
      command:
          - tail
          - -f
          - /dev/null
      volumes:
          - name: volume
            host: ./volume
            container: /volume
      resources:
          cpu: "4"
          memory: 32G
          gpu: nvidia
```

```ini
[volume]
app.volume = ./volume

[resource]
app.cpu = 4
app.memory = 32G
app.gpu = nvidia
```

```json
{
    "arch": ["amd64"],
    "image": "ghcr.io/dxflow-ai/gromacs:latest",
    "version": "2025.2",
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
dxflow workflow create --identity gromacs gromacs.yml

# With a GPU (default), or CPU-only by dropping the gpu resource
dxflow workflow start gromacs
```

The container stays up so you can run `gmx_mpi` commands against data mounted at `/volume`.

### 2. Run a simulation

The `gmx_mpi` commands below run inside the workflow container; put your inputs under `/volume`.

```bash
# Prepare the system
gmx_mpi pdb2gmx -f protein.pdb -o processed.gro -water spce
gmx_mpi editconf -f processed.gro -o newbox.gro -c -d 1.0 -bt cubic
gmx_mpi solvate -cp newbox.gro -cs spc216.gro -o solv.gro -p topol.top

# Energy minimization
gmx_mpi grompp -f em.mdp -c solv.gro -p topol.top -o em.tpr
gmx_mpi mdrun -v -deffnm em

# Production MD (add -nb gpu on a GPU node)
gmx_mpi grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md.tpr
gmx_mpi mdrun -v -deffnm md -nb gpu
```

### 3. Retrieve results

Everything under `/volume` persists — trajectories, logs, and analysis outputs are written there.

## Notes

- **GPU vs CPU**: with a GPU attached, offload work with `mdrun -nb gpu` (and `-pme gpu`, `-bonded gpu`); check `nvidia-smi`. Without a GPU, `gmx_mpi` runs on CPU automatically.
- **MPI parallelism**: launch multiple ranks with `mpirun -np <N> gmx_mpi mdrun -v -deffnm md`; use `-ntomp` for OpenMP threads per rank and `-tunepme yes` for automatic PME tuning.
- Built from source with `-DGMX_SIMD=AVX2_256` and its own bundled FFTW; the `GMXRC` environment is sourced for interactive shells.
- Supports the common force fields (AMBER, CHARMM, GROMOS, OPLS), free-energy and umbrella-sampling methods, and REMD.

## References

- **Website**: [GROMACS](https://www.gromacs.org/)
- **Documentation**: [GROMACS Manual](https://manual.gromacs.org/)
- **Tutorials**: [GROMACS Tutorials](http://www.mdtutorials.com/gmx/)
