# CellBender Checkpoint Bug Fix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10](https://img.shields.io/badge/python-3.10-blue.svg)](https://www.python.org/downloads/)
[![CellBender](https://img.shields.io/badge/CellBender-0.3.2-green.svg)](https://github.com/broadinstitute/CellBender)

An automated setup and execution script for CellBender 0.3.2 that fixes the PyTorch checkpoint pickling bug, enabling successful ambient RNA removal from droplet-based single-cell RNA sequencing data.

## Table of Contents

- [Problem](#problem)
- [Solution](#solution)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Output Files](#output-files)
- [Technical Details](#technical-details)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Citation](#citation)
- [License](#license)

## Problem

CellBender 0.3.2 (installed from GitHub) encounters a critical checkpoint saving error when used with PyTorch 2.x:

```
TypeError: cannot pickle 'weakref.ReferenceType' object
AssertionError: Checkpoint file ckpt.tar.gz does not exist, presumably because 
saving of the checkpoint file has been manually interrupted.
```

This bug prevents CellBender from completing successfully, even though the training procedure finishes correctly and produces valid results. The issue stems from incompatibility between PyTorch 2.x serialization and CellBender's checkpoint mechanism.

## Solution

This repository provides a complete automation script that:

1. ✅ Sets up a clean Python 3.10 virtual environment
2. ✅ Installs CellBender 0.3.2 from GitHub (latest development version)
3. ✅ Applies runtime patches to bypass checkpoint pickling issues
4. ✅ Processes multiple samples with customizable parameters
5. ✅ Organizes outputs into structured directories

**Note**: CellBender 0.3.2 is currently only available from GitHub. The latest PyPI version is 0.3.0, which may have different issues.

## Features

- **Zero Manual Configuration**: Automated environment setup and patching
- **Batch Processing**: Process multiple samples sequentially
- **Flexible Parameters**: Customize cell counts, droplet inclusion, and false positive rates per sample
- **Organized Output**: All results saved in dedicated `cellbender/` subdirectories
- **Comprehensive Logging**: Detailed logs for debugging and quality control
- **GPU Accelerated**: Full CUDA support for faster processing

## Requirements

### Hardware
- CUDA-capable NVIDIA GPU (tested on RTX 3090, GTX 1080 Ti, and newer)
- Minimum 8GB GPU memory (16GB+ recommended for large datasets)

### Software
- Linux or WSL2 (Windows Subsystem for Linux)
- Python 3.10
- CUDA toolkit (compatible with your GPU)

### Input Data
- CellRanger output: `raw_feature_bc_matrix.h5` files
- Organized in directory structure with `outs/` folders

## Installation

### Quick Start

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/cellbender-checkpoint-fix.git
cd cellbender-checkpoint-fix

# Make the script executable
chmod +x complete_cellbender_setup.sh

# Edit configuration (see Configuration section below)
nano complete_cellbender_setup.sh

# Run the script
./complete_cellbender_setup.sh
```

### Manual Download

```bash
# Download the script directly
wget https://raw.githubusercontent.com/YOUR_USERNAME/cellbender-checkpoint-fix/main/complete_cellbender_setup.sh

chmod +x complete_cellbender_setup.sh
```

## Usage

### Basic Workflow

1. **Organize your data** in a directory structure:
   ```
   /path/to/your/data/
   ├── sample1/
   │   └── outs/
   │       └── raw_feature_bc_matrix.h5
   ├── sample2/
   │   └── outs/
   │       └── raw_feature_bc_matrix.h5
   └── sample3/
       └── outs/
           └── raw_feature_bc_matrix.h5
   ```

2. **Edit the script** to match your setup:
   ```bash
   nano complete_cellbender_setup.sh
   ```

3. **Run the script**:
   ```bash
   ./complete_cellbender_setup.sh
   ```

4. **Check outputs** in each sample's `outs/cellbender/` directory

## Configuration

### Required Edits

Edit these variables in `complete_cellbender_setup.sh`:

```bash
# Set your base data directory
BASE_DIR="/path/to/your/data"

# Define your samples
# Format: "FOLDER_NAME:EXPECTED_CELLS:TOTAL_DROPLETS:FPR"
SAMPLES=(
  "sample1:10000:25000:0.01"
  "sample2:8000:20000:0.01"
  "sample3:12000:30000:0.05"
)
```

### Parameter Guide

| Parameter | Description | Recommended Values |
|-----------|-------------|-------------------|
| `EXPECTED_CELLS` | Approximate number of real cells | Check knee plot; typically 5,000-20,000 |
| `TOTAL_DROPLETS` | Droplets to include in analysis | 2-3× expected cells |
| `FPR` | False Positive Rate | 0.01 (strict), 0.05 (moderate), 0.10 (permissive) |

#### Choosing FPR (False Positive Rate)

- **FPR 0.01** (Strict): Use for high-quality samples with good viability
  - Removes more potential background
  - May lose some low-quality real cells
  
- **FPR 0.05** (Moderate): Use for samples with moderate quality or biological stress
  - Balanced approach
  - Recommended for heterogeneous samples
  
- **FPR 0.10** (Permissive): Use for low-quality or damaged tissue samples
  - Retains more cells
  - May include more background contamination
  - Apply stringent downstream QC

### Advanced Configuration

```bash
# Change number of training epochs (default: 150)
--epochs 150

# Adjust learning rate for difficult samples
--learning-rate 0.0001
```

## Output Files

### Directory Structure

After processing, each sample will have:

```
sample_name/
└── outs/
    ├── raw_feature_bc_matrix.h5          # Original input
    └── cellbender/                        # CellBender outputs
        ├── sample_name_CB_v1.h5           # All droplets (raw output)
        ├── sample_name_CB_v1_filtered.h5  # Filtered cells (use this!)
        ├── sample_name_CB_v1_cell_barcodes.csv
        ├── sample_name_CB_v1_metrics.csv
        ├── sample_name_CB_v1_report.pdf   # QC plots
        └── sample_name_cellbender.log     # Processing log
```

### File Descriptions

| File | Purpose |
|------|---------|
| `*_filtered.h5` | **Primary output** - Use this for downstream analysis (Seurat, Scanpy, etc.) |
| `*.h5` | Raw output containing all droplets |
| `*_cell_barcodes.csv` | List of identified cell barcodes |
| `*_metrics.csv` | Summary statistics and QC metrics |
| `*_report.pdf` | Diagnostic plots (if generation succeeds) |
| `*.log` | Complete processing log for debugging |

## Technical Details

### How the Patches Work

The script applies two runtime patches to CellBender's source code:

1. **checkpoint.py**: Replaces checkpoint saving functions with no-op stubs
   - Prevents the `weakref.ReferenceType` pickling error
   - Does not affect model training or final outputs
   
2. **posterior.py**: Safely handles missing checkpoint files
   - Allows the inference procedure to complete without checkpoints
   - Ensures posterior distributions are computed correctly

These patches are **non-invasive** and only disable intermediate checkpoint saving. The final outputs remain unaffected and scientifically valid.

### Why This Works

- CellBender's checkpoints are for **resuming interrupted runs**, not for the final output
- The training completes successfully despite checkpoint errors
- Final results (denoised count matrices) are generated independently of checkpoints
- This solution has been validated on multiple datasets with consistent results

## Troubleshooting

### Common Issues

#### "CUDA out of memory"
```bash
# Solution 1: Reduce total droplets
"sample:10000:20000:0.01"  # Instead of 30000

# Solution 2: Process samples one at a time
# Comment out all but one sample in SAMPLES array
```

#### "No filtered output produced"
```bash
# Check the log file
cat /home/$USER/cellbender_out/sample_name_cellbender.log

# Common causes:
# - Incorrect expected cell count (too high or too low)
# - Input file corrupted or wrong format
# - Insufficient GPU memory
```

#### "File not found" errors
```bash
# Verify your directory structure
ls -R /path/to/your/data/sample_name/outs/

# Expected to see:
# raw_feature_bc_matrix.h5
```

#### Patches don't apply
```bash
# Manually verify CellBender installation
source ~/cb032_fixed/bin/activate
python -c "import cellbender; print(cellbender.__version__)"

# Reinstall if needed
pip uninstall cellbender -y
pip install git+https://github.com/broadinstitute/CellBender.git
```

### Getting Help

If you encounter issues:

1. Check the log file in `cellbender_out/`
2. Review the [CellBender documentation](https://cellbender.readthedocs.io/)
3. Open an issue in this repository with:
   - Error message
   - Your environment (OS, GPU, Python version)
   - Relevant log excerpts

## Downstream Analysis

After CellBender, apply additional quality control filters:

### In Seurat (R)
```r
# Load CellBender output
library(Seurat)
counts <- Read10X_h5("sample_CB_v1_filtered.h5")
seurat_obj <- CreateSeuratObject(counts)

# Apply QC filters
seurat_obj[["percent.mt"]] <- PercentageFeatureSet(seurat_obj, pattern = "^MT-")
seurat_obj <- subset(seurat_obj, 
                     subset = nFeature_RNA > 200 & 
                              nFeature_RNA < 6000 & 
                              percent.mt < 20)
```

### In Scanpy (Python)
```python
# Load CellBender output
import scanpy as sc
adata = sc.read_10x_h5("sample_CB_v1_filtered.h5")

# Calculate QC metrics
sc.pp.calculate_qc_metrics(adata, qc_vars=['mt'], 
                           percent_top=None, log1p=False, inplace=True)

# Apply filters
sc.pp.filter_cells(adata, min_genes=200)
sc.pp.filter_cells(adata, max_genes=6000)
adata = adata[adata.obs.pct_counts_mt < 20, :]
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request

### Areas for Contribution

- Testing on different GPU architectures
- Support for additional CellBender versions
- Integration with workflow managers (Nextflow, Snakemake)
- Automated parameter optimization
- Additional QC visualizations

## Citation

If you use this script in your research, please cite:

**CellBender (primary citation):**
```bibtex
@article{fleming2023cellbender,
  title={Unsupervised removal of systematic background noise from droplet-based single-cell experiments using CellBender},
  author={Fleming, Stephen J and Chaffin, Mark D and Arduini, Alessandro and Akkad, Amer-Denis and Banks, Elena and Marioni, John C and Philippakis, Anthony A and Ellinor, Patrick T and Babadi, Mehrtash},
  journal={Nature Methods},
  volume={20},
  pages={1323--1335},
  year={2023},
  publisher={Nature Publishing Group}
}
```

**This repository:**
```
CellBender Checkpoint Bug Fix (2024)
https://github.com/YOUR_USERNAME/cellbender-checkpoint-fix
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **CellBender team** at the Broad Institute for the original tool
- **PyTorch developers** for the deep learning framework
- Community members who reported and helped debug the checkpoint issue

---

**Disclaimer**: This is a community-developed workaround for a known bug. Always validate outputs against expected biological patterns and known markers. For production use, consider testing on a subset of data first.

**Status**: Actively maintained. Last updated: January 2024
