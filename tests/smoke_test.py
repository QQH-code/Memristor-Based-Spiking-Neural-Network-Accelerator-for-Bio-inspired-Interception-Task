from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def assert_exists(rel_path: str) -> None:
    path = ROOT / rel_path
    if not path.exists():
        raise AssertionError(f"Missing required path: {rel_path}")


def main() -> None:
    required_files = [
        "README.md",
        "CITATION.cff",
        "LICENSE",
        ".gitignore",
        "requirements.txt",
        "environment.yml",
        "audit/REPOSITORY_PREPARATION_REPORT.md",
        "audit/figure_inventory.csv",
        "figures/paper_figures/fig01_task_overview.png",
        "figures/paper_figures/fig02_accelerator_architecture.png",
        "figures/paper_figures/fig03_system_level_result_1.png",
        "figures/paper_figures/fig04_system_level_result_2.png",
        "figures/paper_figures/fig05_neuron_layout.png",
    ]
    required_dirs = [
        "src",
        "src/matlab",
        "src/veriloga",
        "spectre_templates",
        "docs",
        "figures",
        "figures/paper_figures",
        "audit",
        "tests",
    ]
    for rel in required_files + required_dirs:
        assert_exists(rel)

    forbidden_suffixes = {
        ".pdf",
        ".pptx",
        ".log",
        ".print",
        ".mat",
        ".fig",
        ".vsdx",
        ".raw",
        ".tr0",
        ".sw0",
        ".lis",
        ".st0",
        ".ic0",
        ".mt0",
        ".fsdb",
        ".vcd",
    }
    forbidden = [
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob("*")
        if p.is_file() and p.suffix.lower() in forbidden_suffixes
    ]
    if forbidden:
        raise AssertionError(f"Forbidden release artifacts found: {forbidden}")

    print("Release integrity smoke test passed.")


if __name__ == "__main__":
    main()
