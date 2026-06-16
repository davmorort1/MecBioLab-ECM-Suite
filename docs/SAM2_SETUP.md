# SAM2 setup guide

The degradation/tunnel annotation workflow uses SAM2 as a prompt-assisted segmentation backend. The MATLAB application remains the reviewer-facing interface, while SAM2 is called through a local Python installation.

## 1. Install Python environment

Create a Python environment suitable for SAM2. The exact commands depend on your Python distribution and GPU setup. A typical Conda-based workflow is:

```bash
conda create -n sam2 python=3.10
conda activate sam2
```

Then install SAM2 following the official instructions of the SAM2 repository used in your laboratory setup.

## 2. Configure model weights

SAM2 model weights are handled as an external dependency. Store the checkpoint in a local model directory and reference it from the MATLAB-side JSON configuration file.

Example local checkpoint path:

```text
D:/models/sam2/checkpoints/sam2.1_b.pt
```

## 3. Configure MATLAB-side JSON file

Copy or edit:

```text
src/tools/sam2_config.json
```

Example:

```json
{
  "pythonExe": "D:/software/miniconda/envs/sam2/python.exe",
  "repoRoot": "D:/tools/sam2",
  "checkpoint": "D:/models/sam2/checkpoints/sam2.1_b.pt",
  "config": "configs/sam2.1/sam2.1_hiera_b+.yaml"
}
```

Use forward slashes or escaped backslashes in JSON paths. Replace all example paths with the paths used in the local workstation.

## 4. Test the environment

From a terminal:

```bash
conda activate sam2
python --version
```

Then test the SAM2 installation according to the official SAM2 documentation.

## 5. Run the annotation workflow

In MATLAB:

```matlab
run_suite
```

Launch **Degradation/Tunnel Annotation** and load a `.lif` file. The user remains responsible for reviewing masks, accepting valid annotations and rejecting incorrect masks.

## 6. Output interpretation

The workflow exports reviewed masks, labels and metadata. Treat these outputs as expert-reviewed annotations rather than fully automatic ground truth. They are suitable for downstream review, object quantification and future supervised segmentation model development.
