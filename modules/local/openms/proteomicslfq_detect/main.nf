process PROTEOMICSLFQ_DETECT {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2026.10.04' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2026.10.04' }"

    input:
    tuple val(meta), path(ms_file), path(id_file)
    path(expdes)
    path(fasta, stageAs: 'database/*')
    val(feature_args)

    output:
    tuple val(meta), path("feature_checkpoints/*.featureParquet"), emit: checkpoint
    path "*.log", emit: log
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def db_name = fasta.toString().tokenize("/")[-1]
    // The in-process Thermo RAW reader of the pinned OpenMS image cannot open .raw files through
    // symlinks (as staged by Nextflow), so vendor files are passed by their resolved path.
    // The file name stays the same, so run names still match the experimental design.
    def vendorPath = { f -> f.name ==~ /(?i).*\.(raw|d)/ ? "\$(readlink -f ${f})" : "${f}" }
    // Bruker .d m/z values are only correct with the Bruker TDF SDK (open-source approximation: up to ~37 ppm off)
    def has_dotd = [ms_file].any { f -> f.name ==~ /(?i).*\.d/ }

    // Checkpoints record the FASTA by size and modification time. A local copy with a fixed
    // modification time gives every detect task and the combining task the same stamp, wherever
    // the database was staged (Nextflow task hashing already tracks changes of the FASTA content).
    """
    cp -L ${fasta} ${db_name}
    touch -m -d @0 ${db_name}

    ProteomicsLFQ \\
        -threads ${task.cpus} \\
        -in ${vendorPath.call(ms_file)} \\
        -ids ${id_file} \\
        -design ${expdes} \\
        -fasta ${db_name} \\
        -feat_dir feature_checkpoints \\
        -detect_only \\
        ${feature_args} \\
        $args \\
        2>&1 | tee ${ms_file.baseName}_proteomicslfq_detect.log

    if [ "${has_dotd}" = "true" ] && { ! grep -qF 'TIMS calibration: Bruker SDK (m/z + 1/K0)' ${ms_file.baseName}_proteomicslfq_detect.log || grep -F 'TIMS calibration:' ${ms_file.baseName}_proteomicslfq_detect.log | grep -vqF 'Bruker SDK (m/z'; }; then
        echo "ERROR: Bruker .d input was not read with the Bruker TDF SDK m/z calibration (needs the amd64 OpenMS image with libtimsdata). See ${ms_file.baseName}_proteomicslfq_detect.log." >&2
        exit 1
    fi

    rm ${db_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ProteomicsLFQ: \$(ProteomicsLFQ 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
