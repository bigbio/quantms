process PTMSHEPHERD {
    tag "$meta.phil_ptmshep"
    label 'process_low'

    input:
    tuple val(meta), file(mzml_file), file(psm), file(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_global.modsummary.tsv"),  emit: ptmshepherd_sum
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo "
    dataset = ${mzml_file.baseName} $psm \$PWD
    threads = 8
    histo_bindivs = 5000
    histo_smoothbins = 2
    peakpicking_promRatio = 0.3
    peakpicking_width = 0.002
    peakpicking_topN = 500
    precursor_tol = 0.01
    spectra_ppmtol = 20.0
    spectra_condPeaks = 100
    spectra_condRatio = 0.02
    varmod_masses = Failed_Carbamidomethylation:-57.021464
    localization_background = 4
    output_extended = true" > shepherd_config.txt
    java -jar /thirdparty/PTMShepherd/ptmshepherd-0.3.5.jar shepherd_config.txt > ${mzml_file.baseName}_ptmshepherd.log
    mv global.modsummary.tsv ${mzml_file.baseName}_global.modsummary.tsv
    """
}