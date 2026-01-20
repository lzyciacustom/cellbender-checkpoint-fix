#!/bin/bash
# Complete CellBender Setup and Execution Script
# This script sets up a clean CellBender environment with patches to fix checkpoint bugs
# and runs CellBender on all samples with optimized parameters for WT and KO groups

set -euo pipefail

echo "======================================================================"
echo "CellBender Complete Setup and Execution Script"
echo "======================================================================"

# ============================================================================
# STEP 1: Create Clean Python Environment
# ============================================================================
echo ""
echo "STEP 1: Setting up Python environment..."

if [ ! -d ~/cb032_fixed ]; then
    echo "Creating new virtual environment at ~/cb032_fixed"
    python3.10 -m venv ~/cb032_fixed
else
    echo "Environment ~/cb032_fixed already exists, using existing environment"
fi

source ~/cb032_fixed/bin/activate

# ============================================================================
# STEP 2: Install CellBender from GitHub
# ============================================================================
echo ""
echo "STEP 2: Installing CellBender from GitHub..."

pip install --upgrade pip -q
pip install git+https://github.com/broadinstitute/CellBender.git -q

echo "CellBender version: $(cellbender --version)"

# ============================================================================
# STEP 3: Apply Patches to Fix Checkpoint Bug
# ============================================================================
echo ""
echo "STEP 3: Applying patches to fix checkpoint pickling bug..."

# Create patch scripts as separate files
mkdir -p /tmp/cellbender_patches

# Patch checkpoint.py
cat > /tmp/cellbender_patches/patch_checkpoint.py << 'CHECKPOINT_PATCH'
file_path = "/root/cb032_fixed/lib/python3.10/site-packages/cellbender/remove_background/checkpoint.py"

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

# Patch posterior.py
cat > /tmp/cellbender_patches/patch_posterior.py << 'POSTERIOR_PATCH'
file_path = "/root/cb032_fixed/lib/python3.10/site-packages/cellbender/remove_background/posterior.py"

with open(file_path, 'r') as f:
    content = f.read()

content = content.replace(
    "if os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):",
    "if ckpt_posterior and os.path.exists(ckpt_posterior.get('posterior_file', 'does_not_exist')):"
)

content = content.replace(
    "ckpt_posterior.get(",
    "(ckpt_posterior or {}).get("
)

with open(file_path, 'w') as f:
    f.write(content)

print("✓ posterior.py patched")
POSTERIOR_PATCH

# Apply patches
python /tmp/cellbender_patches/patch_checkpoint.py
python /tmp/cellbender_patches/patch_posterior.py

echo "All patches applied successfully!"