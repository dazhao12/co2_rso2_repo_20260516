from __future__ import annotations

import hashlib
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[2]
OUTPUTS = ROOT / "outputs_local"
PACKAGE_DIR = OUTPUTS / "docs" / "manuscript_development" / "package_outputs"
PACKAGE_PATH = PACKAGE_DIR / "CO2_rSO2_manuscript_development_package.zip"


PACKAGE_FILES = [
    ("main/CO2_MANUSCRIPT_DRAFT_V1.docx", "docs/manuscript_development/CO2_MANUSCRIPT_DRAFT_V1.docx"),
    ("main/CO2_MANUSCRIPT_DRAFT_V1.md", "docs/manuscript_development/CO2_MANUSCRIPT_DRAFT_V1.md"),
    (
        "supplement/CO2_SUPPLEMENTARY_METHODS_DRAFT.docx",
        "docs/manuscript_development/CO2_SUPPLEMENTARY_METHODS_DRAFT.docx",
    ),
    (
        "supplement/CO2_SUPPLEMENTARY_METHODS_DRAFT.md",
        "docs/manuscript_development/CO2_SUPPLEMENTARY_METHODS_DRAFT.md",
    ),
    (
        "supplement/CO2_SUPPLEMENTARY_TABLES_INDEX.docx",
        "docs/manuscript_development/CO2_SUPPLEMENTARY_TABLES_INDEX.docx",
    ),
    (
        "supplement/CO2_SUPPLEMENTARY_TABLES_INDEX.md",
        "docs/manuscript_development/CO2_SUPPLEMENTARY_TABLES_INDEX.md",
    ),
    ("tables/table1_cohort_characteristics.csv", "outputs_local/docs/manuscript_development/generated_assets/table1_cohort_characteristics.csv"),
    ("tables/table1_cohort_characteristics.xlsx", "outputs_local/docs/manuscript_development/generated_assets/table1_cohort_characteristics.xlsx"),
    ("tables/table2_clinical_step_contrasts.csv", "outputs_local/docs/manuscript_development/generated_assets/table2_clinical_step_contrasts.csv"),
    ("tables/table2_clinical_step_contrasts.xlsx", "outputs_local/docs/manuscript_development/generated_assets/table2_clinical_step_contrasts.xlsx"),
    (
        "tables/supplementary_etable1_2_cohort_characteristics.xlsx",
        "outputs_local/docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics.xlsx",
    ),
    (
        "tables/supplementary_etable1_2_cohort_characteristics_long.csv",
        "outputs_local/docs/manuscript_development/generated_assets/supplementary_etable1_2_cohort_characteristics_long.csv",
    ),
    ("tables/supplementary_model_diagnostics.csv", "outputs_local/docs/manuscript_development/generated_assets/supplementary_model_diagnostics.csv"),
    ("tables/supplementary_model_diagnostics.xlsx", "outputs_local/docs/manuscript_development/generated_assets/supplementary_model_diagnostics.xlsx"),
    ("tables/table1_2_co2_rso2.xlsx", "outputs_local/results/manuscript_tables/table1_2_co2_rso2.xlsx"),
    ("tables/table1_2_co2_rso2_flow_counts.csv", "outputs_local/results/manuscript_tables/table1_2_co2_rso2_flow_counts.csv"),
    ("tables/table1_2_co2_rso2_long.csv", "outputs_local/results/manuscript_tables/table1_2_co2_rso2_long.csv"),
    ("tables/table1_2_co2_rso2_wide.csv", "outputs_local/results/manuscript_tables/table1_2_co2_rso2_wide.csv"),
    ("tables/supplemental_etable3_artifact_co2_rso2.csv", "outputs_local/results/supplemental_etables/supplemental_etable3_artifact_co2_rso2.csv"),
    (
        "tables/supplemental_etable4_missingness_imputation_other_intraop.csv",
        "outputs_local/results/supplemental_etables/supplemental_etable4_missingness_imputation_other_intraop.csv",
    ),
    ("tables/supplemental_etable5_patient_level_co2_rso2.csv", "outputs_local/results/supplemental_etables/supplemental_etable5_patient_level_co2_rso2.csv"),
    ("tables/supplemental_etable6_model_performance_co2_rso2.csv", "outputs_local/results/supplemental_etables/supplemental_etable6_model_performance_co2_rso2.csv"),
    ("tables/supplemental_etable7_nonparametric_terms_co2_rso2.csv", "outputs_local/results/supplemental_etables/supplemental_etable7_nonparametric_terms_co2_rso2.csv"),
    ("tables/supplemental_etable8_parametric_terms_co2_rso2.csv", "outputs_local/results/supplemental_etables/supplemental_etable8_parametric_terms_co2_rso2.csv"),
    ("tables/Supplemental_eTables3_5_CO2_rSO2.xlsx", "outputs_local/results/supplemental_etables/Supplemental_eTables3_5_CO2_rSO2.xlsx"),
    ("tables/Supplemental_eTables6_8_CO2_rSO2.xlsx", "outputs_local/results/supplemental_etables/Supplemental_eTables6_8_CO2_rSO2.xlsx"),
    ("figures/figure1_cohort_flow.png", "outputs_local/docs/manuscript_development/generated_assets/figure1_cohort_flow.png"),
    ("figures/figure2_etco2_adjusted_curves.png", "outputs_local/docs/manuscript_development/generated_assets/figure2_etco2_adjusted_curves.png"),
    ("figures/figure2_etco2_adjusted_curves.svg", "outputs_local/docs/manuscript_development/generated_assets/figure2_etco2_adjusted_curves.svg"),
    ("figures/figure3_clinical_step_contrasts.png", "outputs_local/docs/manuscript_development/generated_assets/figure3_clinical_step_contrasts.png"),
    ("figures/figure3_clinical_step_contrasts.svg", "outputs_local/docs/manuscript_development/generated_assets/figure3_clinical_step_contrasts.svg"),
    ("figures/figure4_etco2_local_slopes.png", "outputs_local/docs/manuscript_development/generated_assets/figure4_etco2_local_slopes.png"),
    ("source_data/source_data_figure1_cohort_flow.csv", "outputs_local/docs/manuscript_development/generated_assets/source_data_figure1_cohort_flow.csv"),
    ("source_data/source_data_figure2_etco2_curves.csv", "outputs_local/docs/manuscript_development/generated_assets/source_data_figure2_etco2_curves.csv"),
    ("source_data/source_data_figure3_clinical_step.csv", "outputs_local/docs/manuscript_development/generated_assets/source_data_figure3_clinical_step.csv"),
    ("source_data/source_data_figure4_etco2_local_slopes.csv", "outputs_local/docs/manuscript_development/generated_assets/source_data_figure4_etco2_local_slopes.csv"),
    ("documentation/README.md", "docs/manuscript_development/README.md"),
    ("documentation/CO2_SUBMISSION_GAP_CHECKLIST.md", "docs/manuscript_development/CO2_SUBMISSION_GAP_CHECKLIST.md"),
    ("documentation/CO2_TABLES_AND_FIGURES_DRAFT.md", "docs/manuscript_development/CO2_TABLES_AND_FIGURES_DRAFT.md"),
    ("documentation/CO2_TABLE1_2_HPC_RUN_LOG.md", "docs/manuscript_development/CO2_TABLE1_2_HPC_RUN_LOG.md"),
    ("documentation/CO2_TABLE1_EXTRACTION_SPEC.md", "docs/manuscript_development/CO2_TABLE1_EXTRACTION_SPEC.md"),
    ("documentation/CO2_CHANNEL_NAMING_AUDIT.md", "docs/manuscript_development/CO2_CHANNEL_NAMING_AUDIT.md"),
    ("documentation/CO2_SEX_LABEL_AUDIT.md", "docs/manuscript_development/CO2_SEX_LABEL_AUDIT.md"),
    ("documentation/CO2_SENSITIVITY_DECISION.md", "docs/manuscript_development/CO2_SENSITIVITY_DECISION.md"),
    (
        "documentation/CO2_AUTHOR_SUBMISSION_STATEMENTS_TEMPLATE.md",
        "docs/manuscript_development/CO2_AUTHOR_SUBMISSION_STATEMENTS_TEMPLATE.md",
    ),
    ("documentation/CO2_REFERENCE_AUDIT.md", "docs/manuscript_development/CO2_REFERENCE_AUDIT.md"),
    ("documentation/CO2_SOURCE_DATA_PACKAGE_INDEX.md", "docs/manuscript_development/CO2_SOURCE_DATA_PACKAGE_INDEX.md"),
    ("documentation/CO2_NATURE_STYLE_READINESS_AUDIT.md", "docs/manuscript_development/CO2_NATURE_STYLE_READINESS_AUDIT.md"),
    ("documentation/CO2_LITERATURE_AND_POSITIONING.md", "docs/manuscript_development/CO2_LITERATURE_AND_POSITIONING.md"),
    ("documentation/CO2_MANUSCRIPT_BLUEPRINT.md", "docs/manuscript_development/CO2_MANUSCRIPT_BLUEPRINT.md"),
    ("documentation/CO2_PRIOR_MAPCI_FRAMEWORK_EXTRACT.md", "docs/manuscript_development/CO2_PRIOR_MAPCI_FRAMEWORK_EXTRACT.md"),
    ("documentation/CO2_10_ROUND_MANUSCRIPT_REVIEW_LOG.md", "docs/manuscript_development/CO2_10_ROUND_MANUSCRIPT_REVIEW_LOG.md"),
]


def git_value(*args: str) -> str:
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return "unavailable"


def working_tree_dirty() -> bool:
    status = git_value("status", "--short")
    ignored = {"outputs_local/docs/manuscript_development/package_outputs/CO2_rSO2_manuscript_development_package.zip"}
    for line in status.splitlines():
        path = line[2:].strip()
        if path and path not in ignored:
            return True
    return False


def sha256_prefix(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()[:12]


def build_manifest(file_rows: list[dict[str, str]]) -> str:
    commit = git_value("rev-parse", "--short", "HEAD")
    branch = git_value("branch", "--show-current")
    dirty = "yes" if working_tree_dirty() else "no"
    lines = [
        "# CO2-rSO2 Manuscript Development Package Manifest",
        "",
        f"Build date: {datetime.now(timezone.utc).date().isoformat()}",
        f"Git branch: {branch}",
        f"Git commit: {commit}",
        f"Working tree dirty at build: {dirty}",
        "",
        "Status: manuscript-development package, not final submission-ready.",
        "",
        "Remaining gates before final journal submission:",
        "",
        "- Confirm author list, ethics, funding, competing interests, data availability, code availability, contributions, and acknowledgements.",
        "- Decide whether to run and report the planned 5-model sensitivity analysis package.",
        "- Apply target-journal figure sizing, reference styling, and source-data upload conventions.",
        "- Complete rendered DOCX page-level visual QA.",
        "",
        "## Included Files",
        "",
        "| Package path | Repository source | Size, bytes | SHA-256 prefix |",
        "| --- | --- | ---: | --- |",
    ]
    for row in file_rows:
        lines.append(f"| `{row['arcname']}` | `{row['source']}` | {row['size']} | `{row['sha']}` |")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    missing = [src for _, src in PACKAGE_FILES if not (ROOT / src).is_file()]
    if missing:
        joined = "\n".join(f"- {p}" for p in missing)
        raise FileNotFoundError(f"Cannot build manuscript package. Missing files:\n{joined}")

    PACKAGE_DIR.mkdir(parents=True, exist_ok=True)
    file_rows = []
    for arcname, source in PACKAGE_FILES:
        path = ROOT / source
        file_rows.append(
            {
                "arcname": arcname,
                "source": source,
                "size": str(path.stat().st_size),
                "sha": sha256_prefix(path),
            }
        )

    manifest = build_manifest(file_rows)
    with ZipFile(PACKAGE_PATH, "w", compression=ZIP_DEFLATED) as zf:
        zf.writestr("PACKAGE_MANIFEST.md", manifest)
        for arcname, source in PACKAGE_FILES:
            zf.write(ROOT / source, arcname)

    print(f"Wrote {PACKAGE_PATH}")
    print(f"Packaged {len(PACKAGE_FILES)} files plus PACKAGE_MANIFEST.md")


if __name__ == "__main__":
    main()
