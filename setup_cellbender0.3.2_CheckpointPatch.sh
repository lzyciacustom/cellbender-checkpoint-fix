#!/bin/bash
# CellBender Setup Script with Checkpoint Bug Patches
# 
# This script sets up a clean CellBender environment and applies patches
# to fix the checkpoint pickle serialization bug.
#
# Patch Repository: https://github.com/lzyciacustom/cellbender-checkpoint-fix
# Version: 1.0
# Last Updated: 2026-01-29
#
# Usage: ./setup_cellbender_patched.sh

set -euo pipefail

echo "======================================================================"
echo "CellBender Setup with Checkpoint Patches"
echo "Patch Repository: github.com/lzyciacustom/cellbender-checkpoint-fix"
echo "======================================================================"

# ============================================================================
# STEP 1: Clean Environment Setup
# ============================================================================
VENV_PATH=~/cb032_fixed

echo ""
echo "Step 1: Setting up Python environment"
echo "----------------------------------------------------------------------"

if [ -d "$VENV_PATH" ]; then
    echo "Removing existing environment at $VENV_PATH..."
    rm -rf "$VENV_PATH"
fi

echo "Creating fresh virtual environment..."
python3.10 -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

echo "Installing packages..."
pip install --upgrade pip -q
# Install CellBender from GitHub (v0.3.2 or latest)
pip install git+https://github.com/broadinstitute/CellBender.git@v0.3.2 -q
pip install scrublet scanpy -q

echo "✓ Environment created at: $VENV_PATH"
echo "✓ CellBender version: $(cellbender --version)"

# ============================================================================
# STEP 2: Apply Checkpoint Patches
# ============================================================================
echo ""
echo "Step 2: Applying checkpoint patches"
echo "----------------------------------------------------------------------"

SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
CHECKPOINT_FILE="${SITE_PACKAGES}/cellbender/remove_background/checkpoint.py"
POSTERIOR_FILE="${SITE_PACKAGES}/cellbender/remove_background/posterior.py"

echo "Patching: $CHECKPOINT_FILE"
echo "Patching: $POSTERIOR_FILE"

# ============================================================================
# Patch 1: checkpoint.py - Disable checkpoint save/load functions
# ============================================================================
# Problem: CellBender's checkpoint saving fails with pickle serialization errors
# Solution: Replace checkpoint functions with no-ops that skip saving/loading
# Impact: Training continues normally but cannot resume from checkpoints
# ============================================================================
export CHECKPOINT_FILE
python3 << 'CHECKPOINT_PATCH'
import os
import sys

file_path = os.environ.get('CHECKPOINT_FILE')
if not os.path.exists(file_path):
    print(f"✗ checkpoint.py not found at {file_path}")
    sys.exit(1)

with open(file_path, 'r') as f:
    lines = f.readlines()

new_lines = []
skip_function = False
current_function = None

for i, line in enumerate(lines):
    if 'def save_checkpoint(' in line:
        current_function = 'save_checkpoint'
        new_lines.append('def save_checkpoint(*args, **kwargs):\n')
        new_lines.append('    """Patched to skip checkpoint saving due to pickle bug"""\n')
        new_lines.append('    import logging\n')
        new_lines.append('    logger = logging.getLogger(__name__)\n')
        new_lines.append('    logger.info("Checkpoint saving skipped (patched)")\n')
        new_lines.append('    return\n\n')
        skip_function = True
        continue
    elif 'def load_checkpoint(' in line:
        current_function = 'load_checkpoint'
        new_lines.append('def load_checkpoint(*args, **kwargs):\n')
        new_lines.append('    """Patched to skip checkpoint loading"""\n')
        new_lines.append('    return {"loaded": False}\n\n')
        skip_function = True
        continue
    elif 'def load_from_checkpoint(' in line:
        current_function = 'load_from_checkpoint'
        new_lines.append('def load_from_checkpoint(*args, **kwargs):\n')
        new_lines.append('    """Patched to skip checkpoint loading"""\n')
        new_lines.append('    return None\n\n')
        skip_function = True
        continue
    elif 'def attempt_load_checkpoint(' in line:
        current_function = 'attempt_load_checkpoint'
        new_lines.append('def attempt_load_checkpoint(*args, **kwargs):\n')
        new_lines.append('    """Patched to skip checkpoint loading"""\n')
        new_lines.append('    return {"loaded": False}\n\n')
        skip_function = True
        continue
    
    if skip_function:
        if line.startswith('def ') and current_function not in line:
            skip_function = False
            current_function = None
            new_lines.append(line)
        continue
    
    new_lines.append(line)

with open(file_path, 'w') as f:
    f.writelines(new_lines)

print("✓ checkpoint.py patched")
CHECKPOINT_PATCH

# ============================================================================
# Patch 2: posterior.py - Remove checkpoint assertions and add null checks
# ============================================================================
# Problem 1: Assertion fails when checkpoint file doesn't exist (because we disabled it)
# Problem 2: Code tries to access ckpt_posterior dict without checking if it's None
# Solution: Remove assertion and add null safety checks
# ============================================================================
export POSTERIOR_FILE
python3 << 'POSTERIOR_PATCH'
import os
import sys

file_path = os.environ.get('POSTERIOR_FILE')
if not os.path.exists(file_path):
    print(f"✗ posterior.py not found at {file_path}")
    sys.exit(1)

with open(file_path, 'r') as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Skip the entire assertion block (typically 5 lines with backslash continuations)
    if 'assert os.path.exists(args.input_checkpoint_tarball)' in line:
        # Replace with a pass statement
        new_lines.append('    pass  # Checkpoint assertion removed (patched)\n')
        # Skip this line and the next continuation lines
        i += 1
        while i < len(lines) and (lines[i].strip().startswith('f\'') or lines[i-1].rstrip().endswith('\\')):
            i += 1
        continue
    
    # Fix ckpt_posterior null checks
    if "if os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):" in line:
        line = line.replace(
            "if os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):",
            "if ckpt_posterior and os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):"
        )
    
    if "ckpt_posterior.get(" in line and "(ckpt_posterior or {}).get(" not in line:
        line = line.replace("ckpt_posterior.get(", "(ckpt_posterior or {}).get(")
    
    new_lines.append(line)
    i += 1

with open(file_path, 'w') as f:
    f.writelines(new_lines)

print("✓ posterior.py patched")
POSTERIOR_PATCH

# ============================================================================
# STEP 3: Verification
# ============================================================================
echo ""
echo "Step 3: Verification"
echo "----------------------------------------------------------------------"

python3 << 'VERIFY'
import sys
try:
    from cellbender.remove_background import checkpoint, posterior
    print("✓ CellBender imports successfully")
    print("✓ Patches applied and modules load without errors")
except Exception as e:
    print(f"✗ Import error: {e}")
    sys.exit(1)
VERIFY

echo ""
echo "======================================================================"
echo "✓ Setup Complete!"
echo "======================================================================"
echo ""
echo "Environment location: $VENV_PATH"
echo ""
echo "To activate the environment:"
echo "  source $VENV_PATH/bin/activate"
echo ""
echo "To run CellBender:"
echo "  cellbender remove-background --cuda --input <file.h5> --output <out.h5> \\"
echo "    --expected-cells <N> --total-droplets-included <M> --fpr 0.01 --epochs 150"
echo ""
echo "Note: Checkpoint saving/loading is disabled by this patch."
echo "      This is intentional to avoid pickle serialization errors."
echo ""
echo "======================================================================"
