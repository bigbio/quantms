//
// fdr control based on psm/peptide
//

include { ID_SCORE_SWITCHER as IDSCORESWITCHER } from '../../modules/local/openms/id_score_switcher/main'
include { FALSE_DISCOVERY_RATE as FDRCONSENSUSID } from '../../modules/local/openms/false_discovery_rate/main'
include { ID_FILTER as IDFILTER                } from '../../modules/local/openms/id_filter/main'

workflow PSMFDRCONTROL {

    take:
    ch_id_files

    main:
    ch_version = Channel.empty()
    ch_idfilter = Channel.empty()

    if (params.search_engines.split(",").size() == 1) {
        IDSCORESWITCHER(ch_id_files)
        ch_version = ch_version.mix(IDSCORESWITCHER.out.versions)
        ch_idfilter = IDSCORESWITCHER.out.id_score_switcher
    } else {
        FDRCONSENSUSID(ch_id_files)
        ch_version = ch_version.mix(FDRCONSENSUSID.out.versions)
        ch_idfilter = FDRCONSENSUSID.out.id_files_idx_ForIDPEP_FDR
    }
    IDFILTER(ch_idfilter)
    ch_version = ch_version.mix(IDFILTER.out.versions)

    emit:
    id_filtered =IDFILTER.out.id_filtered
    versions = ch_version
}
