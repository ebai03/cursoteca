#!/bin/bash

##############################################################################
# Script: generate_structure_v3.sh (Version 3 - Multi-emphasis with symlinks)
# Purpose: Generate Cursoteca structure with multiple emphases
#
# Usage: bash generate_structure_v3.sh [base_plan_path] [output_path]
#
# Example:
#   bash generate_structure_v3.sh ./fasiculo_ecci.csv ./data
#
# IMPORTANT: The emphasis CSVs (ITI.csv, IS.csv, CC.csv) must be
#            in the same directory as the base plan.
#
##############################################################################

set -e

# ============================================================================
# INITIAL CONFIGURATION
# ============================================================================

BASE_CSV="${1:-.fasiculo_ecci.csv}"
OUTPUT_DIR="${2:-.data}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect location of emphasis CSVs
ITI_CSV="$(dirname "$BASE_CSV")/ITI.csv"
IS_CSV="$(dirname "$BASE_CSV")/IS.csv"
CC_CSV="$(dirname "$BASE_CSV")/CC.csv"

# File validation
if [ ! -f "$BASE_CSV" ]; then
    echo "Error: '$BASE_CSV' not found"
    exit 1
fi

if [ ! -f "$ITI_CSV" ] || [ ! -f "$IS_CSV" ] || [ ! -f "$CC_CSV" ]; then
    echo "Warning: Not all emphasis CSVs were found"
    echo "   Expected: ITI.csv, IS.csv, CC.csv in $(dirname "$BASE_CSV")"
    echo "   Continuing without specific emphases..."
fi

mkdir -p "$OUTPUT_DIR"

echo "Generating Cursoteca structure (v3 - Multi-emphasis)"
echo "Base plan: $BASE_CSV"
echo "Emphases:"
echo "   • ITI: $ITI_CSV $([ -f "$ITI_CSV" ] && echo "(found)" || echo "(not found)")"
echo "   • IS: $IS_CSV $([ -f "$IS_CSV" ] && echo "(found)" || echo "(not found)")"
echo "   • CC: $CC_CSV $([ -f "$CC_CSV" ] && echo "(found)" || echo "(not found)")"
echo "Output: $OUTPUT_DIR"
echo ""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Normalize names with special characters
normalize_name() {
    local input="$1"
    echo "$input" | \
        iconv -f UTF-8 -t ASCII//TRANSLIT | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[[:space:]]\+/_/g' | \
        sed 's/[^a-z0-9_-]//g' | \
        sed 's/_\+/_/g; s/-\+/-/g' | \
        sed 's/^[-_]*//; s/[-_]*$//'
}

# Get YEAR based on cycle
get_year_from_cycle() {
    local cycle="$1"
    if [ "$cycle" = "OPT" ]; then
        echo "OPT"
        return
    fi
    local year=$(( ($cycle - 1) / 2 + 1 ))
    echo "$year"
}

# Get cycle within YEAR (1 or 2)
get_cycle_in_year() {
    local cycle="$1"
    if [ "$cycle" = "OPT" ]; then
        echo "OPT"
        return
    fi
    local cycle_in_year=$(( ($cycle - 1) % 2 + 1 ))
    echo "$cycle_in_year"
}

# Create course folder structure
create_course_structure() {
    local course_dir="$1"
    
    mkdir -p "$course_dir"
    mkdir -p "$course_dir/00_Syllabus"
    mkdir -p "$course_dir/01_Diapositivas"
    mkdir -p "$course_dir/03_Quices"
    mkdir -p "$course_dir/04_Examenes"
}

# ============================================================================
# STEP 1: PROCESS BASE PLAN (MANDATORY COURSES)
# ============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 1: Processing mandatory courses from base plan"
echo "═══════════════════════════════════════════════════════════════"
echo ""

declare -A CURSOS_OBLIGATORIOS  # codigo -> ciclo
declare -A CURSOS_NOMBRES       # codigo -> normalized name

# Process base file
tail -n +2 "$BASE_CSV" 2>/dev/null | while IFS=',' read -r CICLO CODIGO NOMBRE_CURSO; do
    # Clean spaces and special characters
    CICLO=$(echo "$CICLO" | xargs -0 | tr -d '"\n')
    CODIGO=$(echo "$CODIGO" | xargs -0 | tr -d '"\n')
    NOMBRE_CURSO=$(echo "$NOMBRE_CURSO" | xargs -0 | tr -d '"\n')
    
    # Skip empty lines
    [ -z "$CICLO" ] || [ -z "$CODIGO" ] && continue
    
    # Normalize name
    NOMBRE_NORM=$(normalize_name "$NOMBRE_CURSO")
    
    # Get YEAR and cycle
    YEAR=$(get_year_from_cycle "$CICLO")
    CICLO_EN_YEAR=$(get_cycle_in_year "$CICLO")
    
    # Create directory
    if [ "$YEAR" = "OPT" ]; then
        COURSE_DIR="$OUTPUT_DIR/Optativas_Generales/${NOMBRE_NORM}_${CODIGO}"
    else
        COURSE_DIR="$OUTPUT_DIR/Año_${YEAR}/Ciclo_${CICLO_EN_YEAR}/${NOMBRE_NORM}_${CODIGO}"
    fi
    
    #create_course_structure "$COURSE_DIR"
    mkdir -p "$COURSE_DIR"
    echo "[OK] Mandatory: $NOMBRE_CURSO ($CODIGO) -> YEAR $YEAR, Cycle $CICLO_EN_YEAR"
    
done

echo ""

# ============================================================================
# STEP 2: PROCESS EMPHASES (SPECIFIC OPTIONAL COURSES)
# ============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 2: Processing optional courses by emphasis"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Define emphases
declare -A ENFASIS_ARCHIVOS=(
    ["ITI"]="$ITI_CSV"
    ["IS"]="$IS_CSV"
    ["CC"]="$CC_CSV"
)

declare -A ENFASIS_NOMBRES=(
    ["ITI"]="Ingenieria_Tecnologias_Informacion"
    ["IS"]="Ingenieria_Software"
    ["CC"]="Ciencias_Computacion"
)

# Process each emphasis
for ENFASIS in "${!ENFASIS_ARCHIVOS[@]}"; do
    CSV_FILE="${ENFASIS_ARCHIVOS[$ENFASIS]}"
    ENFASIS_DIR_NAME="${ENFASIS_NOMBRES[$ENFASIS]}"
    
    if [ ! -f "$CSV_FILE" ]; then
        echo "Warning: Skipping $ENFASIS: file not found ($CSV_FILE)"
        continue
    fi
    
    echo "EMPHASIS: $ENFASIS ($ENFASIS_DIR_NAME)"
    
    # Read emphasis CSV
    tail -n +2 "$CSV_FILE" 2>/dev/null | while IFS=',' read -r CICLO CODIGO NOMBRE_CURSO; do
        # Clean
        CICLO=$(echo "$CICLO" | xargs -0 | tr -d '"\n')
        CODIGO=$(echo "$CODIGO" | xargs -0 | tr -d '"\n')
        NOMBRE_CURSO=$(echo "$NOMBRE_CURSO" | xargs -0 | tr -d '"\n')
        
        [ -z "$CICLO" ] || [ -z "$CODIGO" ] && continue
        
        # Normalize
        NOMBRE_NORM=$(normalize_name "$NOMBRE_CURSO")
        
        # Create structure: data/Enfasis_X/Optativas/nombre_codigo/
        ENFASIS_OPTATIVAS_DIR="$OUTPUT_DIR/Enfasis_${ENFASIS_DIR_NAME}_Optativas"
        COURSE_DIR="$ENFASIS_OPTATIVAS_DIR/${NOMBRE_NORM}_${CODIGO}"
        
        mkdir -p "$ENFASIS_OPTATIVAS_DIR"
        
        # Check if already exists in Optativas_Generales (to create symlink)
        GENERAL_OPT_DIR="$OUTPUT_DIR/Optativas_Generales/${NOMBRE_NORM}_${CODIGO}"
        
        if [ -d "$GENERAL_OPT_DIR" ]; then
            # Already exists: create symlink
            if [ ! -L "$COURSE_DIR" ] && [ ! -d "$COURSE_DIR" ]; then
                ln -s "../Optativas_Generales/${NOMBRE_NORM}_${CODIGO}" "$COURSE_DIR"
                echo "   ├─ [LINK] $NOMBRE_CURSO ($CODIGO) -> symlink to Optativas_Generales"
            fi
        else
            # Does not exist: create copy
            create_course_structure "$COURSE_DIR"
            echo "   ├─ [OK] $NOMBRE_CURSO ($CODIGO) -> new folder"
        fi
        
    done
    
    echo ""
done

# ============================================================================
# STEP 3: GENERATE DOCUMENTATION
# ============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 3: Generating documentation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Main README.md
README_FILE="$OUTPUT_DIR/README.md"

cat > "$README_FILE" << 'EOF'
# Course Structure - Cursoteca

## Description

**Cursoteca** is a collaborative historical archive of academic materials from the **Computing Bachelor with Multiple Emphases** of the **School of Computer Science and Informatics (ECCI)**.

Organized in two levels:
1. **Mandatory courses**: By YEAR and cycle (main structure)
2. **Optional courses**: By emphasis (ITI, IS, CC) with symlinks to avoid duplication

## General Structure

EOF