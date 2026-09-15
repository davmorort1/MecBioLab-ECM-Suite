# User guide
This guide explains how to use the two public workflows of **3D Mechanobiological Analysis Suite**.

## 1. Purpose
The suite converts collagen-rich confocal microscopy stacks into reproducible outputs for extracellular matrix analysis. The current public release contains two workflows:
1. **Continuous ECM Density Mapping**: extracts threshold-free, continuous full-field ECM density maps from raw confocal stacks, avoiding optical fragmentation and binarization artefacts.
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
- Continuous ECM Density Mapping launcher;
- Degradation/Tunnel Annotation launcher.

Select a clean output location outside the repository before running analyses.

## 4. Continuous ECM Density Mapping

### 4.1 Objective
This module transforms the raw ECM signal into a quantifiable, threshold-free continuous map, avoiding the structural fragmentation caused by binary thresholding.

### 4.2 Key Parameters
*   **ECM / fibers channel:** Select the channel index corresponding to the collagen/ECM signal.
*   **Projection through Z:** Choose how the 3D stack is collapsed (Mean, Median, or Integrated signal). Mean is recommended for standard confocal stacks.
*   **Background subtract pct:** Percentile (e.g., 1%) used to estimate and subtract global background noise.
*   **Denoise sigma px:** Small Gaussian blur applied before mapping to reduce sensor noise (e.g., 0.8).
*   **Final smooth sigma px:** Gaussian blur applied to the final projected heatmap for visualization (e.g., 3).

### 4.3 Main outputs
The module creates a `Module_Continuous_Density` folder containing:
*   `01_Raw_vs_Colormap/`: Side-by-side comparison of raw projection and normalized heatmap.
*   `04_Overlay/`: Raw signal overlaid with the colormap.
*   `05_Z_Profile_Summary/`: Signal decay and max intensity plotted across the Z-axis.
*   `08_Tables/`: CSV/Excel tables containing the Gini Density Coefficient, Densification Index, and Remodelling Contrast Index.

### 4.4 Interpretation
The Gini Density Coefficient and Densification Index provide threshold-free metrics of matrix accumulation and architectural variance. These outputs support the comparison of global matrix heterogeneity across images or experimental conditions without forcing artificial binary segmentation.

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

## 8. Data management and external assets
The repository is designed as a lightweight, citable software release. Full analysis projects typically combine the public code with local assets managed outside GitHub:
- raw confocal acquisitions and exported image stacks;
- complete numerical output folders generated during analysis;
- MATLAB workspaces and large intermediate arrays;
- SAM2 model weights and local Python environments;
- laboratory-specific metadata and project records.

For reproducible use, keep the exported parameter logs, calibration metadata, selected series/position identifiers and quality-control figures together with the corresponding local dataset. The public GitHub repository should remain focused on source code, documentation, compact representative figures and citation metadata.