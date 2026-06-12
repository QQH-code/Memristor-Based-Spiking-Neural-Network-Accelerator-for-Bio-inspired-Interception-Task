# Project Overview

This repository is a curated public research-code release for a memristor-based spiking neural-network (SNN) accelerator for bio-inspired interception tasks.

## Motivation

Bio-inspired interception tasks provide a compact way to study prediction, timing, and closed-loop behavior in dynamic environments. Spiking neural networks are a natural fit for this setting because they represent information with sparse events rather than dense continuous activations.

The hardware motivation is energy-efficient neuromorphic and AI acceleration. Memristor/RRAM-based synaptic computation can support dense analog or mixed-signal multiply-accumulate style operations near memory, while VLSI neuron circuits provide event generation, membrane integration, and spike timing behavior. The associated research explores this intersection using software-level SNN workflows, memristive/crossbar-oriented mapping, and circuit-level simulation.

## What This Repository Provides

- MATLAB workflow scripts for SNN, crossbar, neuron, mapping, waveform-processing, Monte Carlo, and analysis tasks.
- Verilog-A model files used by the research workflow.
- Sanitized Spectre templates documenting how circuit simulations are organized.
- Manually curated public figures associated with the project.
- Citation metadata and release-audit documentation.

## What This Repository Does Not Provide

- A full Cadence/Spectre installation.
- 130 nm PDK/ODK technology files or model libraries.
- Cadence license files or private environment setup files.
- Raw simulator outputs, full run directories, `.print` files, `.mat` files, or `.fig` files.
- A complete turnkey local reproduction of the circuit-level results.

## How To Interpret This Repository

This is a public research-code and workflow-organization package, not a standalone software product. The included files are intended to help readers understand the project structure, inspect public code/model artifacts, and adapt the workflow in their own authorized MATLAB and Cadence/Spectre environments.

