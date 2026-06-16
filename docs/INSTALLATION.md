# Installation guide

This guide describes how to install the public release of **3D Mechano-Biological Analysis Suite**.

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
- Control System Toolbox 24.2

The most important dependency for image processing is **Image Processing Toolbox**. Some optional visualization, compilation or parallel workflows may depend on the other installed toolboxes.

## 2. Download the repository

Clone the repository:

```bash
git clone https://github.com/davmorort1/MecBioLab-ECM-Suite.git
cd MecBioLab-ECM-Suite
```

Alternatively, download the repository as a ZIP file and extract it to a local folder.

## 3. Install Bio-Formats / bfmatlab

The software expects Bio-Formats MATLAB functions to be available in the MATLAB path when reading Leica `.lif` files.

General steps:

1. Download the Bio-Formats MATLAB package from the OME Bio-Formats distribution.
2. Extract it to a stable local folder, for example:

```text
C:/tools/bfmatlab/
```

3. In MATLAB, add the folder to the path:

```matlab
addpath('C:/tools/bfmatlab')
savepath
```

4. Test that the Bio-Formats reader is visible:

```matlab
which bfGetReader
```

If MATLAB returns an empty result, Bio-Formats is not correctly installed in the path.

## 4. Configure SAM2, if needed

SAM2 is required only for the degradation/tunnel annotation workflow. Geodesic Tract Analysis can be used without SAM2.

See [`SAM2_SETUP.md`](SAM2_SETUP.md) for detailed configuration.

## 5. Start the suite

Open MATLAB in the repository root and run:

```matlab
run_suite
```

This command adds the repository source folders to the MATLAB path and opens the graphical launcher.

## 6. Recommended output location

Select an output folder outside the Git repository, for example:

```text
D:/MecBioLab_outputs/
```

Do not export large result folders inside the repository. The `.gitignore` excludes common heavy files, but keeping outputs outside the repository is safer.

## 7. Troubleshooting

### MATLAB cannot find `run_suite`

Make sure the MATLAB current folder is the repository root.

### MATLAB cannot read `.lif` files

Check that Bio-Formats is installed:

```matlab
which bfGetReader
```

### SAM2 does not launch

Check `src/tools/sam2_config.json` and verify that all paths are valid on your local machine.

### Outputs are generated but physical units look wrong

Inspect the Bio-Formats metadata and confirm pixel size and Z-step calibration. Do not interpret physical lengths or volumes if metadata were not read correctly.
