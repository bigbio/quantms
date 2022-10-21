process PTMSHEPHERD {
    label 'process_low'

    container = 'tillenglert/oopenms_post_process:latest'

    input:
    tuple val(meta), file(mzml_file), file(psm), file(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_global.modsummary.tsv"),  emit: ptmshepherd_sum
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    """
    echo "
    dataset = ${mzml_file.baseName} $psm \$PWD
    threads = $task.cpus
    histo_bindivs = 5000
    histo_smoothbins = 2
    peakpicking_promRatio = 0.3
    peakpicking_width = 0.002
    peakpicking_topN = $params.ptmshepherd_peakpicking_TopN
    peakpicking_minPsm = $params.ptmshepherd_peakpicking_minPSM
    precursor_tol = 0.01
    spectra_ppmtol = 20.0
    spectra_condPeaks = 100
    spectra_condRatio = 0.02
    varmod_masses = Failed_Carbamidomethylation:-57.021464
    localization_background = 4" > shepherd_config.txt
    java -jar /thirdparty/PTMShepherd/ptmshepherd-CLI-1.1.1.jar shepherd_config.txt |& tee ${mzml_file.baseName}_ptmshepherd.log
    mv global.modsummary.tsv ${mzml_file.baseName}_global.modsummary.tsv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PTMShepherd: \$(java -jar /thirdparty/PTMShepherd/ptmshepherd-CLI-1.1.1.jar | grep -E version* | sed 's/.*version //g' | sed 's/ University of Michigan//g')
    END_VERSIONS
    """
}