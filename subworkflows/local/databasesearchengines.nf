//
// search engines msgf,comet and index peptide
//

include { SEARCHENGINEMSGF  } from '../../modules/local/openms/thirdparty/searchenginemsgf/main'
include { SEARCHENGINECOMET } from '../../modules/local/openms/thirdparty/searchenginecomet/main'

workflow DATABASESEARCHENGINES {
    take:
    ch_mzmls_search
    ch_searchengine_in_db

    main:
    (ch_id_msgf, ch_id_comet, ch_versions) = [ Channel.empty(), Channel.empty(), Channel.empty() ]

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

    emit:
    ch_id_files_idx = ch_id_msgf.mix(ch_id_comet)

    versions        = ch_versions
}
