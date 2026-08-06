// Refine the OpenMS `-out_qpx` output into a clean, complete QPX dataset.
//
// OpenMS ProteomicsLFQ / IsobaricWorkflow already emit a *partial* QPX
// (psm/feature/pg parquet) via `-out_qpx`, but that output (a) carries raw
// channel labels (run filename / bare index) that need canonicalising and
// (b) lacks the metadata tables (run, sample, ontology, provenance, dataset)
// and the MuData (.h5mu) view. This step runs the `qpx` tool
// (`qpxc convert openms`) over the `-out_qpx` folder + the companion
// consensusXML + the SDRF to produce the final QPX that quantms publishes --
// bringing the DDA path to parity with the DIA-NN (quantmsdiann) QPX.
//
// This replaces the mzTab as the pipeline's published quantification artifact.
// See OpenMS#9817 for the upstream `-out_qpx` labelling fixes; until those land,
// this converter relabels channels downstream from the consensusXML/SDRF.
process QPX_CONVERT {
    tag "${qpx_dir.baseName}"
    label 'process_medium'

    // qpx ships as a Docker image to GitHub Container Registry
    // (ghcr.io/bigbio/qpx) on every release; pin the current release tag.
    // Singularity pulls the same image via docker://.
    container "ghcr.io/bigbio/qpx:1.1.0"

    input:
    path(qpx_dir)
    path(consensusxml)
    path(sdrf)

    output:
    path "${prefix}_qpx", emit: out_qpx
    path "*.log", emit: log
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${sdrf.baseName}"
    // def accession = params.accession ? "--project-accession ${params.accession}" : ''

    """
    qpxc convert openms-consensus \\
        --sdrf-file ${sdrf} \\
        --consensusxml ${consensusxml} \\
        --output-folder ${prefix}_qpx \\
        --output-prefix ${prefix} \\
        ${args} \\
        2>&1 | tee qpx_convert.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qpx: \$(qpxc --version 2>&1 | sed 's/.*version //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
