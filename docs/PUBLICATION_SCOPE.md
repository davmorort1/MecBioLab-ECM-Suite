# Publication scope

This repository contains the public release associated with the SoftwareX manuscript:

**3D Mechanobiological Analysis Suite: an open-source MATLAB toolkit for continuous ECM density mapping and SAM2-assisted matrix degradation annotation**

## Workflows included in v1.1.0

- Continuous ECM Density Mapping.
- SAM2-assisted Degradation and Tunnel Annotation.
- MATLAB graphical launcher.
- Installation and user documentation.
- Reproducibility and output-management documentation.
- Lightweight example figures for quality control.

## External dependencies

The software relies on the following external dependencies, which are not distributed within this repository:

1. **Bio-Formats (bfmatlab):** required for reading `.lif` files and extracting voxel metadata. Distributed by the Open Microscopy Environment (OME).
2. **Segment Anything Model 2 (SAM2):** required for the annotation workflow. Distributed by Meta FAIR.

## Data availability

Microscopy datasets used for the technical evaluation in the manuscript are not included in this repository due to file-size constraints and institutional data-management policies. The repository focuses strictly on the computational implementation and documentation required to reproduce the software environment.