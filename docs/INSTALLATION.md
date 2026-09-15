# Installation guide

This guide describes how to install the public release of **3D Mechanobiological Analysis Suite**.

## 1. Requirements

### 1.1 Tested system

The release was tested on:

- Windows 11
- MATLAB R2024b
- Bio-Formats / bfmatlab for Leica `.lif` reading
- A local Python/SAM2 installation for the annotation workflow

### 1.2 MATLAB toolboxes

The development environment included:

- Image Processing Toolbox 24.2
- Statistics and Machine Learning Toolbox 24.2
- Computer Vision Toolbox 24.2
- Deep Learning Toolbox 24.2
- Parallel Computing Toolbox 24.2
- Medical Imaging Toolbox 24.2
- MATLAB Compiler 24.2

*(Note: Control System Toolbox was installed locally but is not required for the core workflows).*

## 2. MATLAB installation

1. Clone or download the repository to a local folder (e.g. `C:\Projects\MecBioLab-ECM-Suite`).
2. Open MATLAB and navigate to this folder.
3. The `startup.m` or `run_suite.m` script will automatically add `src/tools/` to the MATLAB path during execution.

## 3. Bio-Formats configuration

The software requires Bio-Formats to read physical voxel metadata from proprietary `.lif` files.

1. Download `bfmatlab.zip` from the [Open Microscopy Environment (OME)](https://www.openmicroscopy.org/bio-formats/downloads/).
2. Extract the folder to a permanent location.
3. Add the `bfmatlab` folder to your MATLAB path using `pathtool` or `addpath()`.
4. To verify the installation, type `bfGetReader` in the MATLAB Command Window. If no error appears, the reader is configured.

## 4. SAM2 configuration (Annotation workflow only)

The human-in-the-loop degradation/tunnel annotation workflow uses Segment Anything Model 2 (SAM2) via a Python backend. If you only intend to use the continuous density mapping workflow, this step is not required.

For complete Python, PyTorch, and SAM2 installation instructions, see [SAM2_SETUP.md](SAM2_SETUP.md).

## 5. Verification

1. In the MATLAB Command Window, run `run_suite`.
2. The graphical dashboard should open without errors.
3. Click "Select Root Folder" to choose where outputs will be saved.
4. Launch the desired analysis module.