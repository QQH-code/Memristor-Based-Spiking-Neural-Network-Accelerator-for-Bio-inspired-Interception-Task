# Software-Level Reproduction

This repository does not include an artificial local demo. The previous toy LIF quick-start was removed because it was not part of the paper workflow.

What users can do locally:

- Inspect the MATLAB scripts under `src/matlab/`.
- Inspect the Verilog-A model files under `src/veriloga/`.
- Review sanitized Spectre workflow templates.
- Run repository-integrity checks with:

```bash
python tests/smoke_test.py
```

What users cannot reproduce from this repository alone:

- Full transistor-level or mixed-signal circuit simulations.
- Complete Spectre waveform generation.
- PDK/ODK-dependent results.
- Analyses that require omitted generated `.print`, `.mat`, or raw simulator files.

The included files are intended to document and organize the research workflow while respecting licensing, privacy, and artifact-size boundaries.

