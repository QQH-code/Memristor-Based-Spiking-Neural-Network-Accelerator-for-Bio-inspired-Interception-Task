# Repository Curation Notes

Source material root:

`$SOURCE_MATERIAL_ROOT`

Public release target:

`$PUBLIC_REPO_ROOT`

The requested source folder name `SNN_snntorch_spectre_rram_stf_version 2 3`
was not present. The available source folders were inspected, and
`SNN_snntorch_spectre_rram_stf_version3` was used as the primary source because
it is the newest version by name and contains the most complete Spectre/SNN flow.

The full PDF paper, full PPTX deck, generated Spectre logs, `.print` files,
`.mat` files, `.fig` files, and local binary project artifacts were not copied.
The final public figure set was copied from the manually curated figure folder
into `figures/paper_figures/`.

Private machine paths were replaced with placeholders including:

- `$PROJECT_ROOT`
- `$SOURCE_MATERIAL_ROOT`
- `$PDK_ROOT`
- `$SPECTRE_BIN`
- `$CADENCE_HOME`

## Copied/Sanitized Files

See `audit/source_to_public_file_map.csv`.
