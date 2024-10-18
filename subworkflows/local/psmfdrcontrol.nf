//
// fdr control based on psm/peptide
//

include { IDSCORESWITCHER                      } from '../../modules/local/openms/idscoreswitcher/main'
include { FALSEDISCOVERYRATE as FDRCONSENSUSID } from '../../modules/local/openms/falsediscoveryrate/main'
include { IDFILTER                             } from '../../modules/local/openms/idfilter/main'

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
