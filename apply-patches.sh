#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_NAME="apply-patches"
PATCHES_DIR="${1:-patches}"
REPO_PATH="${2:-.}"

log() {
    echo -e "${GREEN}[${SCRIPT_NAME}]${NC} $1"
}

error() {
    echo -e "${RED}[${SCRIPT_NAME} ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[${SCRIPT_NAME} WARNING]${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[${SCRIPT_NAME} INFO]${NC} $1"
}

if [ ! -d "$REPO_PATH/.git" ] && [ ! -f "$REPO_PATH/.git" ] && ! git -C "$REPO_PATH" rev-parse --git-dir > /dev/null 2>&1; then
    error "The specified path '$REPO_PATH' is not a Git repository or submodule."
fi

if [ ! -d "$PATCHES_DIR" ]; then
    error "Patches directory '$PATCHES_DIR' does not exist!"
fi

PATCH_FILES=($(find "$PATCHES_DIR" -name "*.patch" -type f | sort))
PATCH_COUNT=${#PATCH_FILES[@]}

if [ $PATCH_COUNT -eq 0 ]; then
    warning "No .patch files found in '$PATCHES_DIR'. Nothing to apply."
    exit 0
fi

log "Found $PATCH_COUNT patch files to apply to repository at '$REPO_PATH'"

APPLIED=0
FAILED=0

for patch_file in "${PATCH_FILES[@]}"; do
    patch_name=$(basename "$patch_file")
    patch_file_abs=$(readlink -f "$patch_file")
    
    log "Applying patch: $patch_name"
    
    info "Checking if patch can be applied..."
    if git -C "$REPO_PATH" apply --check "$patch_file_abs"; then
        info "✓ Patch check passed"
        
        info "Applying patch..."
        if git -C "$REPO_PATH" apply "$patch_file_abs"; then
            info "✓ Patch applied successfully"
            APPLIED=$((APPLIED + 1))
        else
            warning "✗ Failed to apply patch despite successful check"
            FAILED=$((FAILED + 1))
            git -C "$REPO_PATH" apply -v "$patch_file_abs" || true
            error "Failed to apply patch: $patch_name"
        fi
    else
        warning "✗ Patch check failed"
        FAILED=$((FAILED + 1))
        git -C "$REPO_PATH" apply -v --check "$patch_file_abs" || true
        error "Failed to apply patch (check failed): $patch_name"
    fi
done

log "Patch application completed: $APPLIED applied, $FAILED failed"

if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
