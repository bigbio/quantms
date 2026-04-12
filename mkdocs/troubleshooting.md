# Troubleshooting

This page covers the most common problems encountered when running quantms, their likely causes, and how to fix them. If your issue is not listed here, see [How to Report Bugs](#how-to-report-bugs) at the bottom of this page.

---

## Pipeline Fails at the Database Search Step

**Symptom:** The pipeline exits with an error in the `COMET`, `MSGF`, or `SAGE` process. You may see `OutOfMemoryError`, `Killed`, or the process just hangs indefinitely.

**Cause:** The database search is the most memory-intensive step. Very large FASTA databases (e.g. metagenomics databases, six-frame translated genomes) or a large number of variable modifications can require tens of gigabytes of RAM per process. By default, Nextflow may allocate insufficient memory to the process.

**Solution:** Increase the per-process memory limit and/or reduce the database size.

```bash
# Increase resource limits globally
nextflow run bigbio/quantms \
    -profile docker \
    --max_memory 64.GB \
    --max_cpus 16 \
    -params-file params.yaml

# Or override just the search process in a custom config
# custom.config
process {
    withName: 'COMET' {
        memory = '32 GB'
        cpus   = 8
    }
}
```

```bash
nextflow run bigbio/quantms -profile docker -c custom.config -params-file params.yaml
```

Additional tips:

- Use a reviewed/canonical FASTA database (e.g. UniProt Swiss-Prot) rather than TrEMBL or the full unreviewed set.
- Limit variable modifications to 1–2; each additional variable mod multiplies the search space.
- Remove stop-codon characters (`*`) from the FASTA file — some search engines fail silently on them.

---

## No Proteins Identified (or Very Few)

**Symptom:** The pipeline completes, but the output mzTab has zero or unexpectedly few protein entries. The QC report shows 0% identification rate or near-zero PSM counts.

**Cause:** Several independent issues can produce this result:

1. Wrong or incomplete protein database (e.g., mouse data searched against human sequences).
2. FDR threshold set too strictly (e.g., `--fdr_threshold 0.001` on a small dataset).
3. Wrong enzyme or missed modifications (e.g., data collected with LysC but Trypsin specified).
4. Spectra files are empty or in the wrong format (conversion failed silently).

**Solution:**

```bash
# Check the database species matches your sample
grep "^>" uniprot_human.fasta | head -5

# Relax FDR threshold (default 0.01 is usually appropriate)
--fdr_threshold 0.01

# Check enzyme specification (use PSI-MS ontology terms in SDRF)
# In SDRF: comment[cleavage agent details] = MS:1001251  (Trypsin)
#          comment[cleavage agent details] = MS:1001309  (LysC)

# Check that mzML files contain spectra
msconvert --filter "peakPicking" input.raw -o .
```

!!! tip "Start with the test profile"
    If you suspect a configuration problem, first run `nextflow run bigbio/quantms -profile test,docker`. This uses a built-in small dataset and should always produce identifications. If the test profile fails, the issue is in your installation.

---

## TMT Channels Not Quantified

**Symptom:** The pipeline runs without error, but the quantification columns in the mzTab output are empty (`null`) or contain only zeros for some or all TMT channels.

**Cause:** The label type specified on the command line or in the SDRF does not match the actual reporter ion masses in the data. For example, specifying `TMT6plex` when the data was acquired with TMT10plex means the pipeline looks for the wrong reporter ion masses.

**Solution:** Verify and correct the `--label_type` parameter (or the `comment[label]` column in the SDRF).

```bash
# Command-line fix
--label_type TMT10plex    # not TMT6plex

# SDRF fix — each row for a TMT channel should have the correct label
# source name    comment[label]
# sample_126     TMT10plex-126
# sample_127N    TMT10plex-127N
# sample_128C    TMT10plex-128C
# ...
```

Also check:

- The `--labelling_type isobaric` flag is present (it is not the default).
- The MS acquisition method actually collected HCD reporter ions (TMT requires HCD or EThcD, not CID at typical settings).
- The fragment mass tolerance covers the reporter ion region — a tolerance of 0.02 Da (default) is appropriate for Orbitrap data; for ion-trap MS2, use 0.5 Da.

---

## Raw File Conversion Failures

**Symptom:** The pipeline fails at the `THERMORAWFILEPARSER` or `DOTD_CONVERSION` step. Error messages may include `failed to convert`, `no spectra found`, or `format not supported`.

**Cause (Thermo .raw files):** ThermoRawFileParser runs in Mono/.NET and can fail if:

- The `.raw` file is from a very old instrument firmware.
- The container image is outdated.
- The file is corrupted or partially uploaded.

**Cause (Bruker .d files):** Bruker TIMS data (`.d` directories) require a separate conversion step and the flag `--convert_dotd true`.

**Solution:**

```bash
# For Thermo .raw files — verify the file is readable
docker run --rm -v $(pwd):/data \
    quay.io/biocontainers/thermorawfileparser:1.4.3--ha8f3691_0 \
    ThermoRawFileParser.sh -i /data/run1.raw -o /data/ -f 2

# For Bruker .d files — enable the conversion step
--convert_dotd true

# Pre-convert to mzML yourself using msconvert (ProteoWizard)
docker run --rm -v $(pwd):/data \
    chambm/pwiz-skyline-i-agree-to-the-vendor-licenses \
    wine msconvert /data/run1.raw --outdir /data/
```

!!! tip "Use mzML when possible"
    If you have access to the original instrument workstation, convert raw files to mzML yourself using Proteowizard msconvert before running quantms. This gives you the most control over conversion options and avoids any container compatibility issues.

---

## Nextflow Resume Not Working

**Symptom:** Adding `-resume` to the command re-runs all tasks from scratch instead of reusing cached results.

**Cause:** Resume depends on the Nextflow work directory (`work/`) being present and the task inputs being identical. Cache invalidation is triggered by:

- Changing any parameter value (including `--outdir`).
- Modifying the input files (even changing the timestamp without changing content can sometimes invalidate cache).
- Deleting or moving the `work/` directory.
- Upgrading Nextflow to a new version.
- Running with a different pipeline revision (`-r`).

**Solution:**

```bash
# Always run from the same directory and with the same params file
nextflow run bigbio/quantms -resume -profile docker -params-file params.yaml

# Check which tasks are being cached vs. re-run
nextflow log  # shows execution history
nextflow log <run-name> -f name,status,hash

# Do not clean the work directory between runs if you want to resume
# Only clean when you want to start fresh:
nextflow clean -f
```

!!! tip "Pin the pipeline version"
    Use `-r 1.3.0` to pin a specific release. Omitting `-r` always pulls the latest commit, which changes the pipeline revision and invalidates the cache.

---

## Docker / Singularity Permission Issues

**Symptom:** Tasks fail with permission denied errors when reading input files or writing output. Messages like `Permission denied: /data/...` or `Cannot write to outdir`.

**Cause:** Docker containers run as root by default, or as a different UID than the host user. Files written by the container may not be readable by the host user, or host directories mounted into the container may not be writable.

**Solution:**

```bash
# Run Docker containers as your own user
docker run --user $(id -u):$(id -g) ...

# In Nextflow, set the Docker user in nextflow.config
docker {
    runOptions = "--user $(id -u):$(id -g)"
}

# For Singularity on HPC — Singularity usually runs as the host user by default.
# If you still have issues, check that the bind paths are correct:
singularity {
    runOptions = "--bind /scratch:/scratch"
}

# Make sure the outdir is writable by your user
mkdir -p results/ && ls -la results/
```

On shared HPC systems, also verify that the scratch or work filesystem is accessible from compute nodes and not just login nodes.

---

## Cloud Execution Failures

**Symptom:** The pipeline fails when reading from or writing to S3 / GCS / Azure Blob Storage. Errors include `Access Denied`, `NoSuchBucket`, `InvalidAccessKeyId`, or the pipeline hangs waiting for cloud resources.

**Cause (S3):** AWS credentials are not available in the environment, the bucket policy does not allow the IAM role used by AWS Batch, or the S3 path is incorrect.

**Cause (GCS):** The service account does not have the Storage Object Admin role on the bucket, or the bucket and the Life Sciences API are in different regions.

**Solution (AWS):**

```bash
# Verify credentials are configured
aws sts get-caller-identity
aws s3 ls s3://my-bucket/

# Pass credentials via environment variables if not using IAM roles
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1

# S3 paths must use s3:// protocol, not s3a:// or https://
--input s3://my-bucket/experiment.sdrf.tsv   # correct
--outdir s3://my-bucket/results/
-work-dir s3://my-bucket/work/
```

```bash
# Verify GCS access
gcloud auth application-default login
gsutil ls gs://my-bucket/

# Nextflow GCS config
google {
    project = 'my-gcp-project'
    location = 'us-central1'
}
```

!!! tip "Use versioned S3 paths"
    Avoid using S3 paths that end with a trailing slash in the SDRF `comment[file uri]` column. Always use full object keys: `s3://bucket/prefix/run1.mzML`.

---

## How to Check Pipeline Logs

Nextflow writes structured logs that help diagnose failures at any step.

```bash
# Show all recent runs
nextflow log

# Show per-task status for the most recent run
nextflow log last -f name,status,exit,workdir

# Inspect the log, stdout, and stderr of a failed task
# Replace <workdir> with the path shown by the command above
cat <workdir>/.command.log     # combined output
cat <workdir>/.command.out     # stdout only
cat <workdir>/.command.err     # stderr only
cat <workdir>/.command.sh      # exact command that was run
cat <workdir>/.command.run     # Nextflow wrapper script

# Show the full Nextflow execution log
cat .nextflow.log
```

For long-running jobs, tail the log in real time:

```bash
tail -f .nextflow.log
```

---

## How to Report Bugs

If you have confirmed the issue is not covered above and is not a local configuration problem, please open an issue on GitHub:

**[https://github.com/bigbio/quantms/issues](https://github.com/bigbio/quantms/issues)**

Please include:

1. The full command you ran (with parameters).
2. The Nextflow version (`nextflow -v`) and pipeline version (`-r`).
3. The container runtime and version (`docker --version` or `singularity --version`).
4. The contents of `.nextflow.log` (attach as a file).
5. The contents of `.command.log` and `.command.err` from the failed task's work directory.
6. A minimal reproducible example if possible (e.g., a small SDRF + a few spectra files that trigger the error).

The more detail you provide, the faster the issue can be diagnosed and resolved.
