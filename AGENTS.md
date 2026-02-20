# AI Agent Guidelines for quantms Development

This document provides comprehensive guidance for AI agents working with the **quantms** bioinformatics pipeline. These guidelines ensure code quality, maintainability, and compliance with project standards.

## 🚨 Critical: Mandatory Validation Before ANY Commit

**ALWAYS run pre-commit hooks before committing ANY changes:**

```bash
pre-commit run --all-files
```

This is **non-negotiable**. All code must pass formatting and style checks before being committed.

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Validation Workflow](#validation-workflow)
4. [Testing Strategy](#testing-strategy)
5. [Development Conventions](#development-conventions)
6. [CI/CD Awareness](#cicd-awareness)
7. [Common Tasks](#common-tasks)
8. [Troubleshooting](#troubleshooting)

---

## Project Overview

**quantms** is an nf-core bioinformatics best-practice analysis pipeline for **Quantitative Mass Spectrometry (MS)**. It supports three major analytical workflows:

- **DDA-LFQ**: Data-dependent acquisition with label-free quantification
- **DDA-ISO**: Data-dependent acquisition with isobaric labeling (TMT, iTRAQ)
- **DIA-LFQ**: Data-independent acquisition with label-free quantification

**Key Features:**

- Built with Nextflow DSL2
- Integrates multiple search engines: Comet, MSGF+, Sage, DIA-NN
- Uses OpenMS tools for proteomics processing
- Statistical analysis with MSstats
- Quality control with pmultiqc
- Complies with nf-core standards

**Repository:** https://github.com/bigbio/quantms
**Documentation:** https://quantms.readthedocs.io/

---

## Technology Stack

### Core Technologies

- **Nextflow**: >=25.04.0 (DSL2 syntax)
- **nf-schema plugin**: 2.5.1 (parameter validation)
- **nf-test**: Testing framework (config: `nf-test.config`)
- **nf-core tools**: Pipeline standards and linting
- **Containers**: Docker/Singularity/Apptainer/Podman (Conda deprecated)

### Key Configuration Files

- `nextflow.config` - Main pipeline configuration (541 lines)
- `nextflow_schema.json` - Parameter schema (auto-generated)
- `nf-test.config` - Testing configuration
- `.nf-core.yml` - nf-core compliance settings
- `modules.json` - Module dependencies
- `.pre-commit-config.yaml` - Pre-commit hooks

### Project Structure

```
quantms/
├── main.nf                    # Pipeline entry point
├── workflows/                 # Main workflows (quantms.nf, lfq.nf, tmt.nf, dia.nf)
├── subworkflows/local/        # Reusable subworkflows
├── modules/                   # Process definitions
│   ├── local/                 # Custom modules
│   ├── bigbio/                # BigBio shared modules
│   └── nf-core/               # nf-core modules
├── conf/                      # Configuration files
│   ├── base.config            # Resource definitions
│   ├── modules/               # Module-specific configs
│   └── tests/                 # Test profile configs (13 profiles)
├── tests/                     # nf-test test cases
├── bin/                       # Utility scripts (R scripts for MSstats)
└── assets/                    # Pipeline assets and schemas
```

---

## Validation Workflow

### 1. Pre-commit Hooks (MANDATORY)

**Installation:**

```bash
pip install pre-commit
pre-commit install  # Install git hooks (one-time setup)
```

**Run before EVERY commit:**

```bash
pre-commit run --all-files
```

**Configured Hooks** (`.pre-commit-config.yaml`):

1. **Prettier** (v3.1.0 with prettier@3.6.2)
   - Formats code consistently across multiple file types
   - Auto-fixes formatting issues

2. **trailing-whitespace**
   - Removes trailing whitespace (preserves markdown linebreaks)

3. **end-of-file-fixer**
   - Ensures files end with a single newline

**Excluded Files:**

- `CHANGELOG.md` (manually maintained)
- `modules/nf-core/**` (managed by nf-core)
- `subworkflows/nf-core/**` (managed by nf-core)
- `*.snap` (test snapshots)

**Auto-fix in CI:**
If you forget to run pre-commit locally, comment on your PR:

```
@nf-core-bot fix linting
```

The bot will run pre-commit and push fixes automatically.

### 2. Pipeline Linting (RECOMMENDED)

**Run before creating PR:**

```bash
nf-core pipelines lint
```

**For master branch PRs:**

```bash
nf-core pipelines lint --release
```

This validates:

- nf-core pipeline standards compliance
- File structure and naming
- Configuration completeness
- Documentation requirements

### 3. Schema Validation (REQUIRED for parameter changes)

**After adding/modifying parameters in `nextflow.config`:**

```bash
nf-core pipelines schema build
```

This updates `nextflow_schema.json` with interactive prompts to add descriptions and validation rules.

---

## Testing Strategy

### Testing Philosophy

**Do NOT run the full test suite before every commit.** The CI system runs comprehensive tests automatically. Instead:

1. **Pre-commit hooks**: ALWAYS (fast, catches style issues)
2. **Targeted tests**: Run tests relevant to your changes
3. **CI validation**: Trust the CI to catch integration issues

### When to Run Tests Locally

#### 🟢 Documentation/Config-Only Changes

**No testing required:**

- README, CHANGELOG, docs/ updates
- Minor config tweaks (labels, descriptions)
- Comment additions
- Asset file updates (email templates, correction matrices)

#### 🟡 Targeted Testing Required

**Run specific test profile(s):**

| Change Area             | Test Profile(s)             | Command                                                                     |
| ----------------------- | --------------------------- | --------------------------------------------------------------------------- |
| LFQ workflow            | `test_lfq`                  | `nextflow run . -profile test_lfq,docker --outdir results`                  |
| TMT/iTRAQ workflow      | `test_tmt`                  | `nextflow run . -profile test_tmt,docker --outdir results`                  |
| TMT with correction     | `test_tmt_corr`             | `nextflow run . -profile test_tmt_corr,docker --outdir results`             |
| DIA workflow            | `test_dia`                  | `nextflow run . -profile test_dia,docker --outdir results`                  |
| PTM localization        | `test_localize`             | `nextflow run . -profile test_localize,docker --outdir results`             |
| Sage search engine      | `test_lfq_sage`             | `nextflow run . -profile test_lfq_sage,docker --outdir results`             |
| AlphaPeptDeep rescoring | `test_dda_id_alphapeptdeep` | `nextflow run . -profile test_dda_id_alphapeptdeep,docker --outdir results` |
| MS2PIP rescoring        | `test_dda_id_ms2pip`        | `nextflow run . -profile test_dda_id_ms2pip,docker --outdir results`        |

#### 🔴 Comprehensive Testing Required

**Run nf-test suite:**

```bash
# Run all tests with nf-test
nf-test test --profile debug,test,docker --verbose

# Or run specific test file
nf-test test tests/default.nf.test --profile debug,test,docker --verbose
```

**When to run comprehensive tests:**

- Core pipeline logic changes (main.nf, quantms.nf)
- Cross-cutting subworkflow modifications
- Module changes affecting multiple workflows
- Before final PR submission (optional but recommended)

### Test Configuration Files

All test profiles are in `conf/tests/`:

- `test_lfq.config` - Quick LFQ test (default)
- `test_tmt.config` - TMT isobaric labeling
- `test_tmt_corr.config` - TMT with plex correction
- `test_dia.config` - DIA label-free
- `test_latest_dia.config` - Latest DIA version
- `test_localize.config` - PTM localization
- `test_lfq_sage.config` - LFQ with Sage
- `test_full_lfq.config` - Full-size LFQ dataset
- `test_full_tmt.config` - Full-size TMT dataset
- `test_full_dia.config` - Full-size DIA dataset
- `test_dda_id_alphapeptdeep.config` - AlphaPeptDeep rescoring
- `test_dda_id_ms2pip.config` - MS2PIP rescoring
- `test_dda_id_fine_tuning.config` - Fine-tuning workflow

### Snapshot Testing

The pipeline uses snapshot-based testing (`tests/default.nf.test`):

- Compares stable file names and content
- Validates workflow success
- Ignores volatile files (pipeline_info/\*.{html,json,txt})

**Updating snapshots after intentional changes:**

```bash
nf-test test --profile debug,test,docker --update-snapshot
```

---

## Development Conventions

### Branch Strategy

- **Target branch**: `dev` (NOT master)
- **Master branch**: Release-ready code only
- **PR process**: Fork → feature branch → PR to `dev`

### Naming Conventions

#### Channel Names

**Initial output from a process:**

```groovy
ch_output_from_<process_name>
```

**Intermediate/terminal channels:**

```groovy
ch_<previous_process>_for_<next_process>
```

**Examples:**

```groovy
ch_output_from_comet
ch_comet_for_fdr_control
ch_fdr_for_protein_inference
```

#### Process/Module Names

- Use lowercase with underscores: `peptide_indexer`, `protein_inference`
- Be descriptive: `OPENMS_PERCOLATORADAPTER` not `PERCOLATOR`
- Follow nf-core conventions for consistency

### Resource Labels

Defined in `conf/base.config`:

| Label              | CPU | Memory | Time | Use Case              |
| ------------------ | --- | ------ | ---- | --------------------- |
| `process_single`   | 1   | 6 GB   | 4h   | Single-threaded tools |
| `process_tiny`     | 1   | 1 GB   | 1h   | Minimal processing    |
| `process_very_low` | 2   | 12 GB  | 4h   | Light parallelism     |
| `process_low`      | 4   | 36 GB  | 8h   | Moderate workload     |
| `process_medium`   | 8   | 72 GB  | 16h  | Standard processing   |
| `process_high`     | 12  | 108 GB | 20h  | Heavy computation     |

**Usage in process:**

```groovy
process MY_PROCESS {
    label 'process_medium'

    cpus task.cpus
    memory task.memory
}
```

### Adding a New Step

When adding a new processing step to the pipeline:

1. **Define input/output channels** in the workflow
2. **Write process block** in `modules/local/` or reuse from nf-core/bigbio
3. **Add parameters** to `nextflow.config` with sensible defaults
4. **Update schema**:
   ```bash
   nf-core pipelines schema build
   ```
5. **Add parameter validation** (type, range, enum constraints)
6. **Perform local testing** with appropriate test profile
7. **Add test configuration** in `conf/tests/` if needed
8. **Update MultiQC config** (`assets/multiqc_config.yml`) if generates reports
9. **Update documentation**:
   - `docs/usage.md` - Parameter descriptions
   - `docs/output.md` - Output file descriptions
10. **Update CHANGELOG.md** and `CITATIONS.md` if adds new tools

### Module Configuration

Module-specific settings in `conf/modules/modules.config`:

```groovy
withName: 'OPENMS_PERCOLATORADAPTER' {
    ext.args = [
        params.fdr_threshold ? "-score_type q-value -threshold ${params.fdr_threshold}" : '',
        params.train_FDR ? "-train_FDR ${params.train_FDR}" : ''
    ].join(' ').trim()
    publishDir = [
        path: { "${params.outdir}/intermediate_results/fdr_control" },
        mode: params.publish_dir_mode,
        pattern: '*.idXML'
    ]
}
```

### Code Style

- **Indentation**: 4 spaces (enforced by Prettier)
- **Line length**: Aim for <120 characters
- **Comments**: Use `//` for single-line, `/* */` for multi-line
- **Strings**: Use single quotes `'text'` unless interpolation needed `"$var"`
- **Groovy closures**: Follow Nextflow DSL2 patterns

---

## CI/CD Awareness

### GitHub Actions Workflows

Understanding what runs automatically helps you anticipate issues:

#### 1. **Linting** (`.github/workflows/linting.yml`)

**Triggers**: All PRs, releases
**Runs**:

- Pre-commit hooks (prettier, whitespace, EOF)
- `nf-core pipelines lint` (with `--release` for master PRs)

**Artifacts**: `lint_log.txt`, `lint_results.md`

#### 2. **CI Testing** (`.github/workflows/ci.yml`)

**Triggers**: Push to dev/master, PRs, releases
**Matrix**:

- Nextflow: `25.04.0`
- Test profiles: All 7 main profiles (lfq, tmt, dia, localize, sage, alphapeptdeep, ms2pip)
- Container: Docker

**Steps**:

1. Checkout with full history
2. Setup Java 17
3. Install Nextflow
4. Free disk space
5. Run pipeline with test profile
6. Upload artifacts on failure

**Artifacts**: Failed logs, results, nextflow logs (timestamped)

**Concurrency**: Cancels in-progress runs for same PR

#### 3. **Extended CI** (`.github/workflows/ci_extended.yml`)

**Matrix**:

- Nextflow: `25.04.0` + `latest-everything`
- Test profiles: All 8 profiles including `test_tmt_corr`
- Runs without `dev` profile on master

#### 4. **Branch Protection** (`.github/workflows/branch.yml`)

**Purpose**: Prevents direct PRs to master
**Action**: Only allows PRs from `dev` or `patch` branches

#### 5. **Auto-fix Linting** (`.github/workflows/fix-linting.yml`)

**Trigger**: Comment `@nf-core-bot fix linting` on PR
**Action**: Runs pre-commit, commits fixes, pushes changes

### What This Means for You

✅ **You don't need to run all tests locally** - CI does this
✅ **Pre-commit failures in CI** - Use `@nf-core-bot fix linting`
✅ **Test failures** - Check artifacts for logs
✅ **Lint failures** - Run `nf-core pipelines lint` locally first
✅ **Branch errors** - Ensure PRs target `dev` not `master`

---

## Common Tasks

### Setting Up Development Environment

```bash
# Clone repository
git clone https://github.com/bigbio/quantms.git
cd quantms

# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Install nf-core tools
pip install nf-core

# Install nf-test (if testing locally)
# See: https://code.askimed.com/nf-test/installation/
```

### Making Changes

```bash
# 1. Create feature branch from dev
git checkout dev
git pull origin dev
git checkout -b feature/my-new-feature

# 2. Make your changes
# ... edit files ...

# 3. Run pre-commit (MANDATORY)
pre-commit run --all-files

# 4. Update schema if parameters changed
nf-core pipelines schema build

# 5. Run targeted tests (if code changes)
nextflow run . -profile test_lfq,docker --outdir results_test

# 6. Commit changes
git add .
git commit -m "feat: add new feature"

# 7. Push and create PR
git push origin feature/my-new-feature
# Create PR to dev branch on GitHub
```

### Updating nf-core Modules

```bash
# List installed modules
nf-core modules list local

# Update specific module
nf-core modules update <module_name>

# Update all modules
nf-core modules update --all
```

### Running Pipeline Locally

```bash
# Basic test run
nextflow run . -profile test,docker --outdir results

# With debug output
nextflow run . -profile debug,test,docker --outdir results

# Specific test profile
nextflow run . -profile test_lfq,docker --outdir results

# Resume from cache
nextflow run . -profile test,docker --outdir results -resume

# Custom parameters
nextflow run . -profile test,docker \
    --outdir results \
    --enable_mod_localization \
    --mod_residues 'S,T,Y' \
    --mod_mass_shift 79.966331
```

### Checking Pipeline Reports

After running pipeline, check these files in `results/`:

- `pipeline_info/execution_report.html` - Resource usage
- `pipeline_info/execution_timeline.html` - Timeline visualization
- `pipeline_info/execution_trace.txt` - Detailed trace
- `multiqc/multiqc_report.html` - Quality control report

---

## Troubleshooting

### Pre-commit Issues

**Problem**: Pre-commit hook fails with formatting issues

```
Files were modified by this hook. Additional output:
```

**Solution**: The files were auto-fixed. Stage and commit again:

```bash
git add .
git commit -m "your message"
```

---

**Problem**: Pre-commit is slow on large changesets

**Solution**: Run on specific files only:

```bash
pre-commit run --files path/to/file1.nf path/to/file2.config
```

---

### Testing Issues

**Problem**: Test fails with "Process exceeded memory limit"

**Solution**: Ensure you're using the `test` profile with resource limits:

```bash
nextflow run . -profile test,docker --outdir results
```

The `test` profile sets `process.memory = 6.GB` and `process.cpus = 2` for CI compatibility.

---

**Problem**: Snapshot test fails after intentional output changes

**Solution**: Update snapshots:

```bash
nf-test test --profile debug,test,docker --update-snapshot
```

Then commit the updated `.snap` files.

---

**Problem**: Container not found / pulling issues

**Solution**:

1. Check internet connection
2. Use alternative container engine:
   ```bash
   nextflow run . -profile test,singularity --outdir results
   ```
3. For Wave-enabled containers, add `wave` profile:
   ```bash
   nextflow run . -profile test,docker,wave --outdir results
   ```

---

**Problem**: Test data not accessible

**Solution**: Test data is hosted on GitHub. Ensure:

1. Internet connectivity
2. No firewall blocking GitHub raw content
3. Try with `-resume` to use cached data

---

### Nextflow Issues

**Problem**: "Nextflow version is too old"

**Solution**: Update Nextflow:

```bash
nextflow self-update
# Or install specific version
export NXF_VER=25.04.0
nextflow -version
```

---

**Problem**: "Process terminated with exit code 137"

**Solution**: Out of memory. Either:

1. Use test profile: `-profile test,docker`
2. Increase Docker memory limit in Docker Desktop settings
3. Reduce `params.max_memory` in config

---

**Problem**: "Error executing process > WORKFLOW:SUBWORKFLOW:PROCESS"

**Solution**:

1. Check `.nextflow.log` for details:
   ```bash
   tail -100 .nextflow.log
   ```
2. Check work directory for process error:
   ```bash
   cat work/<hash>/.command.err
   cat work/<hash>/.command.log
   ```
3. Rerun with more verbose output:
   ```bash
   nextflow run . -profile debug,test,docker --outdir results
   ```

---

### Schema/Parameter Issues

**Problem**: "Unknown parameter"

**Solution**:

1. Check if parameter is in `nextflow.config`
2. Update schema:
   ```bash
   nf-core pipelines schema build
   ```
3. Validate against schema:
   ```bash
   nf-core pipelines schema validate params.json
   ```

---

**Problem**: Schema build fails / JSON validation error

**Solution**:

1. Check `nextflow_schema.json` syntax:
   ```bash
   cat nextflow_schema.json | jq .
   ```
2. If corrupted, restore from git:
   ```bash
   git checkout nextflow_schema.json
   nf-core pipelines schema build
   ```

---

### CI/CD Issues

**Problem**: CI tests pass locally but fail in GitHub Actions

**Solution**: Common causes:

1. **Resource limits**: CI has stricter limits (2 CPU, 6 GB RAM)
2. **Test profile**: Ensure using `test` profile in CI config
3. **Container differences**: CI uses different architecture (amd64)
4. **Timeouts**: CI has time limits, may need to optimize slow processes

---

**Problem**: Lint check fails in CI but passes locally

**Solution**:

1. Ensure using same nf-core version:
   ```bash
   # Check version in .nf-core.yml
   pip install nf-core==<version>
   ```
2. Run lint with same flags as CI:
   ```bash
   nf-core pipelines lint
   # For master PRs:
   nf-core pipelines lint --release
   ```

---

**Problem**: `@nf-core-bot fix linting` doesn't work

**Solution**:

1. Check bot has write permissions to your fork
2. Ensure PR is from a branch (not fork's master)
3. Manually run and commit:
   ```bash
   pre-commit run --all-files
   git add .
   git commit -m "style: apply pre-commit fixes"
   git push
   ```

---

### Module/Subworkflow Issues

**Problem**: "Module not found" error

**Solution**:

1. Check `modules.json` for module entry
2. Install module:
   ```bash
   nf-core modules install <module_name>
   ```
3. For local modules, verify path in `modules/local/`

---

**Problem**: Module config not applied

**Solution**: Check `conf/modules/modules.config`:

1. Use correct selector: `withName: 'EXACT_PROCESS_NAME'`
2. Process names are case-sensitive
3. For subworkflow processes: `withName: '.*:SUBWORKFLOW:PROCESS'`

---

### General Debugging Tips

1. **Always check `.nextflow.log`** - Contains detailed error info
2. **Inspect work directory** - Failed process outputs in `work/<hash>/`
3. **Use `-resume`** - Saves time by using cached results
4. **Enable debug profile** - More verbose logging: `-profile debug`
5. **Check resource usage** - View `pipeline_info/execution_report.html`
6. **Test incrementally** - Test small changes before big refactors
7. **Use nf-test** - Unit test individual processes/subworkflows

---

## Additional Resources

- **Pipeline Documentation**: https://quantms.readthedocs.io/
- **nf-core Guidelines**: https://nf-co.re/docs/guidelines
- **Nextflow Documentation**: https://www.nextflow.io/docs/latest/
- **nf-test Documentation**: https://code.askimed.com/nf-test/
- **GitHub Discussions**: https://github.com/bigbio/quantms/discussions
- **Issues**: https://github.com/bigbio/quantms/issues

---

## Quick Reference

### Essential Commands

```bash
# Pre-commit (MANDATORY before commit)
pre-commit run --all-files

# Lint pipeline
nf-core pipelines lint

# Update schema
nf-core pipelines schema build

# Run LFQ test
nextflow run . -profile test_lfq,docker --outdir results

# Run TMT test
nextflow run . -profile test_tmt,docker --outdir results

# Run DIA test
nextflow run . -profile test_dia,docker --outdir results

# Run nf-test suite
nf-test test --profile debug,test,docker --verbose

# Update snapshots
nf-test test --profile debug,test,docker --update-snapshot

# Resume pipeline
nextflow run . -profile test,docker --outdir results -resume

# Clean work directory
nextflow clean -f
```

### File Locations

- **Main config**: `nextflow.config`
- **Schema**: `nextflow_schema.json`
- **Pre-commit config**: `.pre-commit-config.yaml`
- **nf-test config**: `nf-test.config`
- **Test configs**: `conf/tests/*.config`
- **Module configs**: `conf/modules/modules.config`
- **Base resources**: `conf/base.config`
- **Main workflow**: `workflows/quantms.nf`
- **Entry point**: `main.nf`

---

**Last Updated**: January 14, 2026
**Pipeline Version**: 1.8.0dev
**Minimum Nextflow**: 25.04.0
