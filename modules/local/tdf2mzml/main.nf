
// process TDF2MZML {
//      publishDir "${params.mzml_dir}/${outputDir}", pattern: "*.mzML.gz", failOnError: true
//      container 'mfreitas/tdf2mzml:latest' // I don't know which stable tag to use...
//      label 'process_single'
//      label 'error_retry'
// 
//      input:
//          tuple val(file_id), path(tdf_input), val(outputDir)
// 
//      output:
//      tuple val(file_id), path("${file(tdf_input.baseName).baseName}.mzML.gz")
// 
//      script:
//      """
//      echo "Unpacking..."
//      tar -xvf ${tdf_input}
//      echo "Converting..."
//      tdf2mzml.py -i *.d # --ms1_type "centroid"
//      echo "Compressing..."
//      mv *.mzml ${file(tdf_input.baseName).baseName}.mzML
//      gzip ${file(tdf_input.baseName).baseName}.mzML
//      """
// 
//      stub:
//      """
//      touch ${file(tdf_input.baseName).baseName}.mzML.gz
//      """
//  } 


process TDF2MZML {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'process_single'
    label 'error_retry'

    // conda "conda-forge::mono bioconda::thermorawfileparser=1.3.4"
    // conda is not enabled for DIA so ... disabling anyway
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/thermorawfileparser:1.3.4--ha8f3691_0' :
    //    'quay.io/biocontainers/thermorawfileparser:1.3.4--ha8f3691_0' }"
    // TODO add support for singularity ...
    container 'mfreitas/tdf2mzml:latest' // I don't know which stable tag to use...

    stageInMode {
        if (task.attempt == 1) {
            if (executor == "awsbatch") {
                'symlink'
            } else {
                'link'
            }
        } else if (task.attempt == 2) {
            if (executor == "awsbatch") {
                'copy'
            } else {
                'symlink'
            }
        } else {
            'copy'
        }
    }

    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    path "*.d",   emit: dotd_files
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    echo "Unpacking..." | tee --append ${rawfile.baseName}_conversion.log
    tar -xvf ${rawfile} 2>&1 | tee --append ${rawfile.baseName}_conversion.log
    echo "Converting..." | tee --append ${rawfile.baseName}_conversion.log
    tdf2mzml.py -i *.d 2>&1 | tee --append ${rawfile.baseName}_conversion.log
    echo "Compressing..." | tee --append ${rawfile.baseName}_conversion.log
    mv *.mzml ${file(rawfile.baseName).baseName}.mzML
    # gzip ${file(rawfile.baseName).baseName}.mzML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tar: \$(tar --version)
        tdf2mzml.py: \$(tdf2mzml.py --version)
    END_VERSIONS
    """
}
