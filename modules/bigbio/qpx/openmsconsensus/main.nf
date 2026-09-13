process QPX_OPENMSCONSENSUS {
    tag "qpx_openmsconsensus"
    label 'process_medium'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    // qpx is published to GHCR on every release (immediately available on tag);
    // a single image serves Docker (native) and Singularity (via docker://).
    // BioContainers/Galaxy-depot lag the release, so GHCR is used for containers;
    // -profile conda still resolves the bioconda package in environment.yml.
    container "ghcr.io/bigbio/qpx:1.1.4"

    input:
    path(consensusxml)
    path(sdrf)
    val(project_accession)

    output:
    path "qpx_output/*", emit: qpx_dataset
    // Optional: the parquet views are the dataset's source of truth, so a MuData
    // view that cannot be built must not destroy an otherwise complete run.
    path "*.h5mu"      , emit: mudata, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args ?: ''
    def prefix  = project_accession ?: 'openms'
    def acc_arg = project_accession ? "--project-accession ${project_accession}" : ''
    """
    set -o pipefail
    qpxc convert openms-consensus \\
        --consensusxml ${consensusxml} \\
        --sdrf-file ${sdrf} \\
        ${acc_arg} \\
        --output-folder qpx_output \\
        --output-prefix ${prefix} \\
        --compression zstd \\
        ${args}

    python - <<'PY'
import shutil
from pathlib import Path

from qpx.mudata import write_dataset_mudata

# Use qpx's own writer rather than build_mudata + mdata.write. It refuses a
# MuData that is missing a required quantification modality, writes via a
# temporary file, and drops a stale view if the build fails. Calling
# build_mudata directly bypassed that check: a modality that failed to build
# was logged and skipped, so an INCOMPLETE h5mu was written and the task
# exited 0 (bigbio/qpx#316 - MSV000085836 shipped proteins with no precursors).
written = write_dataset_mudata(Path("qpx_output"), "${prefix}")
if written is None:
    print("WARNING: no MuData view was written; see the log above. "
          "The qpx_output parquet views are complete and authoritative.")
else:
    shutil.move(str(written), "${prefix}.h5mu")
    print(f"MuData -> ${prefix}.h5mu")
PY

    cat <<-END_VERSIONS > versions.yml
"${task.process}":
    qpx: \$(qpxc --version 2>&1 | sed 's/^qpx //')
    mudata: \$(python -c 'import mudata; print(mudata.__version__)')
END_VERSIONS
    """

    stub:
    def prefix = project_accession ?: 'openms'
    """
    mkdir -p qpx_output
    touch qpx_output/stub.parquet
    touch ${prefix}.h5mu

    cat <<-END_VERSIONS > versions.yml
"${task.process}":
    qpx: stub
    mudata: stub
END_VERSIONS
    """
}
