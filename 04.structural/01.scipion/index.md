---
title: Scipion
description: Integrated image processing framework for cryo-electron microscopy
navigation:
    icon: i-diphyx:scipion
---

Scipion is a workflow-based image processing framework for obtaining 3D models of macromolecular complexes using cryo-EM data. It integrates several software packages while presenting a unified, web-based interface.

## Configuration

```yaml
name: scipion
tags:
  - structural
steps:
  - name: scipion
    platform: docker
    mode: parallel
    image: diphyx/scipion:latest
    env:
      - DXF_PROXY_MAIN_PORT=6082
      - DXF_PROXY_ADDITIONAL_PORTS=6100
      - DXF_PROXY_TOOLBAR=/vnc.html
      - DXF_PROXY_TOOLBAR_SOFTWARE=vnc
    ports:
      - host: "5901"
        container: "5901"
      - host: "6082"
        container: "6082"
      - host: "6100"
        container: "6100"
    volumes:
      - host: ./volume
        container: /volume
    resources:
      cpu: "16"
      memory: 64G
      gpu: nvidia
```

## Usage

### 1. Prepare data

```bash
# Create the data directory
mkdir -p volume
```

### 2. Deploy

```bash
dxflow workflow create --identity scipion scipion.yml
dxflow workflow start scipion
```

Access the desktop by opening your browser at `http://localhost:6082/vnc.html`.

### 3. Monitor

```bash
dxflow workflow logs --live scipion
```

### 4. Retrieve results

Results are written to the mounted `./volume` directory.

## Typical workflow

1. **Import movies** - Import raw cryo-EM movies
2. **Motion correction** - Correct beam-induced motion
3. **CTF estimation** - Estimate contrast transfer function
4. **Particle picking** - Pick particles (manual/automatic)
5. **2D classification** - Classify and average particles
6. **3D initial model** - Generate initial 3D model
7. **3D refinement** - Refine to high resolution
8. **Post-processing** - Sharpen and validate map

## Integrated packages

- **RELION** - Refinement and classification
- **Xmipp** - Complete processing suite
- **EMAN2** - 2D/3D reconstruction
- **CTFfind4** - CTF estimation
- **MotionCor2** - Motion correction
- **Gautomatch** - Particle picking

## Requirements

**Workstation:**
- CPU: 16+ cores
- RAM: 64GB minimum
- GPU: NVIDIA RTX 3090 or better
- Storage: 2TB+ NVMe SSD

## References

- **Website**: [Scipion](http://scipion.i2pc.es/)
- **Documentation**: [Scipion Docs](http://scipion.i2pc.es/docs/docs/user/user-documentation)
- **Tutorials**: [Scipion Tutorials](http://scipion.i2pc.es/docs/docs/user/tutorials)
