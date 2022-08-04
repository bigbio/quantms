//
// fdr control based on psm/peptide
//

include { IDSCORESWITCHER } from '../../modules/local/openms/idscoreswitcher/main'
include { FALSEDISCOVERYRATE as FDRCONSENSUSID } from '../../modules/local/openms/falsediscoveryrate/main'
include { IDFILTER } from '../../modules/local/openms/idfilter/main'

workflow PSMFDRCONTROL {
    take:
    id_files

    main:
    ch_version = Channel.empty()
    ch_idfilter = Channel.empty()

    if (params.search_engines.split(",").size() == 1) {
        IDSCORESWITCHER(id_files)
        ch_version = ch_version.mix(IDSCORESWITCHER.out.version)
        ch_idfilter = IDSCORESWITCHER.out.id_score_switcher
    } else {
        FDRCONSENSUSID(id_files)
        ch_version = ch_version.mix(FDRCONSENSUSID.out.version)
        ch_idfilter = FDRCONSENSUSID.out.id_files_idx_ForIDPEP_FDR
    }
    IDFILTER(ch_idfilter)
    ch_version = ch_version.mix(IDFILTER.out.version)

    emit:
    id_filtered =IDFILTER.out.id_filtered

    version = ch_version
}
