#!/usr/bin/env bash
set -euo pipefail

: "${SPECTRE_BIN:=spectre}"
: "${PDK_MODEL_FILE:?Set PDK_MODEL_FILE to the public/local model path}"
: "${RRAM_MODEL_FILE:?Set RRAM_MODEL_FILE to src/veriloga/RRAM_v_2_1_Beta.va or your local model}"

NETLIST="${1:-spectre_templates/netlist_templates/crossbar_neuron_template.scs}"
OUTDIR="${2:-runs/spectre_example}"
mkdir -p "$OUTDIR"

"$SPECTRE_BIN" "$NETLIST" +escchars +log "$OUTDIR/spectre.log" -format psfxl -raw "$OUTDIR/raw"
