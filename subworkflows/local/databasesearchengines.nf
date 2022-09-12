//
// search engines msgf,comet and index peptide
//

include { SEARCHENGINEMSGF } from '../../modules/local/openms/thirdparty/searchenginemsgf/main'
include { SEARCHENGINECOMET} from '../../modules/local/openms/thirdparty/searchenginecomet/main'
include { SEARCHENGINEMSFRAGGER } from '../../modules/local/openms/thirdparty/searchenginemsfragger/main'

workflow DATABASESEARCHENGINES {
    take:
    ch_mzmls_search
    ch_searchengine_in_db

    main:
    (ch_id_msgf, ch_id_comet, ch_id_msfragger, ch_pepx_msfragger, ch_versions) = [ Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty() ]

    if (params.search_engines.contains("msgf")){
        SEARCHENGINEMSGF(ch_mzmls_search.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(SEARCHENGINEMSGF.out.version)
        ch_id_msgf = ch_id_msgf.mix(SEARCHENGINEMSGF.out.id_files_msgf)
    }

    if (params.search_engines.contains("comet")){
        SEARCHENGINECOMET(ch_mzmls_search.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(SEARCHENGINECOMET.out.version)
        ch_id_comet = ch_id_comet.mix(SEARCHENGINECOMET.out.id_files_comet)
    }

    if (params.search_engines.contains("msfragger")){
        SEARCHENGINEMSFRAGGER(ch_mzmls_search.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(SEARCHENGINEMSFRAGGER.out.version)
        ch_id_msfragger = ch_id_msfragger.mix(SEARCHENGINEMSFRAGGER.out.id_files_msfragger)
        ch_pepx_msfragger = ch_pepx_msfragger.mix(SEARCHENGINEMSFRAGGER.out.pepxml_files_msfragger)
    }

    emit:
    ch_id_files_idx  = ch_id_msgf.mix(ch_id_comet).mix(ch_id_msfragger)
    ch_id_files_pepx = ch_pepx_msfragger
    versions         = ch_versions
}
