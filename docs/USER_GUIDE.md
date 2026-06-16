# User guide

This guide explains how to use the two public workflows of **3D Mechano-Biological Analysis Suite**.

## 1. Purpose

The suite converts collagen-rich confocal microscopy stacks into reproducible outputs for extracellular matrix analysis. The current public release contains two workflows:

1. **Geodesic Tract Analysis**: estimates putative 3D ECM tracts between segmented cell regions and summarizes their geometry with calibrated descriptors.
2. **SAM2-assisted Degradation and Tunnel Annotation**: supports expert-reviewed annotation of degradation/tunnel-like ECM regions and exports reviewed masks, semantic labels and object metrics.

The software is intended for ECM bioimage analysis. Numerical outputs should be interpreted as image-derived structural descriptors unless validated against independent biological or mechanical measurements.

## 2. Expected input data

The workflows are designed for Leica `.lif` confocal datasets containing:

- an ECM/collagen channel;
- optionally a cell channel;
- one or more positions/series;
- multiple Z-planes;
- physical metadata for pixel size and Z-step.

The software uses Bio-Formats / bfmatlab to read `.lif` data and retrieve metadata. If calibration metadata are unavailable or incorrectly read, review all exported physical units before interpreting distances, areas or volumes.

## 3. Starting the suite

Open MATLAB in the repository root and run:

```matlab
run_suite
```

The dashboard opens with:

- global output-folder selector;
- Geodesic Tract Analysis launcher;
- Degradation/Tunnel Annotation launcher.

Select a clean output location outside the repository before running analyses.

## 4. Geodesic Tract Analysis

### 4.1 Objective

This workflow estimates putative 3D structural tracts between segmented cell regions through collagen-rich ECM. It treats the ECM signal as a continuous traversal-cost field rather than as a perfect discrete fiber graph.

### 4.2 Conceptual workflow

1. Load a `.lif` file.
2. Select the relevant image series/position.
3. Read voxel calibration from Bio-Formats metadata.
4. Select ECM and cell channels.
5. Segment cell regions from the cell channel.
6. Smooth and normalize the ECM signal.
7. Convert ECM intensity into a traversal-cost volume.
8. Compute geodesic routes between accepted cell regions.
9. Extract path coordinates and local tract neighborhoods.
10. Summarize tract geometry with tensor descriptors.
11. Export tables, figures, parameters and intermediate files.

### 4.3 Main outputs

Typical outputs include:

- 3D geodesic tract renderings;
- geodesic path coordinate arrays;
- physical tract length and cell-pair identifiers;
- fractional anisotropy and linearity descriptors;
- inertia maps and path-overlaid review figures;
- CSV/XLSX/MAT summary tables;
- parameter logs and quality-control figures.

This workflow does **not** generate reviewed degradation/tunnel masks or semantic segmentation datasets. Those outputs belong to the SAM2-assisted annotation workflow.

### 4.4 Interpretation

High fractional anisotropy and high linearity indicate that the computed tract is elongated and directionally coherent. The outputs can support comparison of matrix organization across images or experimental conditions.

Do not describe a tract as a direct measurement of active mechanical force transmission unless supported by independent measurements.

## 5. SAM2-assisted Degradation and Tunnel Annotation

### 5.1 Objective

This workflow supports expert-reviewed annotation of degradation/tunnel-like ECM regions in confocal Z-planes. SAM2 is used as a segmentation assistant; the reviewer remains responsible for accepting, correcting or rejecting masks.

### 5.2 Conceptual workflow

1. Load a `.lif` file.
2. Select the ECM channel and relevant series/position.
3. Export raw Z-plane images for review.
4. Provide prompts or review SAM2-assisted segmentation candidates.
5. Accept positive masks or mark planes as no-degradation/no-tunnel.
6. Export binary masks and multiclass semantic labels.
7. Reconstruct connected 3D degradation/tunnel objects from reviewed planes.
8. Export object-level measurements and review figures.

### 5.3 Main outputs

Typical outputs include:

- raw image planes;
- accepted binary masks;
- no-tunnel/no-degradation labels;
- multiclass semantic masks;
- image/mask pairs for supervised learning;
- connected 3D degradation/tunnel object measurements;
- review overlays and 3D renderings;
- metadata and parameter logs.

### 5.4 Interpretation

The exported masks are expert-reviewed image annotations. They can support quantitative analysis of degradation/tunnel-like regions and can also be reused as curated training data for future segmentation models.

## 6. Quality control

Before using exported tables:

1. inspect the representative figures;
2. confirm that image calibration is correct;
3. check that selected channels match the intended ECM/cell channels;
4. verify that masks reflect biologically meaningful structures;
5. record parameter settings and dataset identifiers.

## 7. Reproducibility checklist

For each analysis run, keep:

- software version;
- Git commit if available;
- MATLAB version;
- operating system;
- Bio-Formats version if known;
- input file name and series/position;
- channel assignments;
- parameter logs;
- output folder;
- reviewer identity or review protocol for manual annotations.

## 8. What not to upload to GitHub

Do not upload:

- `.lif`, `.czi`, `.nd2`, `.ims` microscopy datasets;
- full `.tif` image stacks;
- result `.mat` files;
- SAM2 checkpoints;
- Python environments;
- personal absolute paths;
- private laboratory data.
