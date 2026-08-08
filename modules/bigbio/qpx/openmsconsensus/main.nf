process QPX_OPENMSCONSENSUS {
    tag "qpx_openmsconsensus"
    label 'process_medium'
    label 'error_retry'

    conda "${moduleDir}/environment.yml"
    // qpx is published to GHCR on every release (immediately available on tag);
    // a single image serves Docker (native) and Singularity (via docker://).
    // BioContainers/Galaxy-depot lag the release, so GHCR is used for containers;
    // -profile conda still resolves the bioconda package in environment.yml.
    container "ghcr.io/bigbio/qpx:1.1.2"

    input:
    path(consensusxml)
    path(sdrf)
    val(project_accession)

    output:
    path "qpx_output/*", emit: qpx_dataset
    path "*.h5mu"      , emit: mudata
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
from qpx.dataset import Dataset
from qpx.mudata import build_mudata

ds = Dataset("qpx_output")
mdata = build_mudata(ds)
mdata.write("${prefix}.h5mu")
ds.close()
print(f"MuData: {mdata.n_obs} obs x {mdata.n_vars} vars -> ${prefix}.h5mu")
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
