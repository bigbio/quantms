
include { MSGF_DB_INDEXING } from '../../modules/local/utils/msgf_db_indexing/main'
include { MSGF  } from '../../modules/local/openms/msgf/main'
include { COMET } from '../../modules/local/openms/comet/main'
include { SAGE  } from '../../modules/local/openms/sage/main'


workflow DATABASE_SEARCH_ENGINE {
    take:
    ch_mzmls_search
    ch_searchengine_in_db

    main:
    (ch_id_msgf, ch_id_comet, ch_id_sage, ch_versions) = [ Channel.empty(), Channel.empty(), Channel.empty(), Channel.empty() ]

    if (params.search_engines.contains("msgf")) {
        MSGF_DB_INDEXING(ch_searchengine_in_db)
        ch_versions = ch_versions.mix(MSGF_DB_INDEXING.out.versions)

        MSGF(ch_mzmls_search.combine(ch_searchengine_in_db).combine(MSGF_DB_INDEXING.out.msgfdb_idx))
        ch_versions = ch_versions.mix(MSGF.out.versions)
        ch_id_msgf = ch_id_msgf.mix(MSGF.out.id_files_msgf)
    }

    if (params.search_engines.contains("comet")) {
        COMET(ch_mzmls_search.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(COMET.out.versions)
        ch_id_comet = ch_id_comet.mix(COMET.out.id_files_comet)
    }

    // sorted mzmls to generate same batch ids when enable cache
    ch_mzmls_sorted_search = ch_mzmls_search.collect(flat: false, sort: { a, b -> a[0]["mzml_id"] <=> b[0]["mzml_id"] }).flatMap()
    if (params.search_engines.contains("sage")) {
        cnt = 0
        ch_meta_mzml_db = ch_mzmls_sorted_search.map{ metapart, mzml ->
            cnt++
            def groupkey = metapart.labelling_type +
                    metapart.dissociationmethod +
                    metapart.fixedmodifications +
                    metapart.variablemodifications +
                    metapart.precursormasstolerance +
                    metapart.precursormasstoleranceunit +
                    metapart.fragmentmasstolerance +
                    metapart.fragmentmasstoleranceunit +
                    metapart.enzyme
            // TODO this only works if the metakeys are all the same
            //  otherwise we need to group by key first and then batch
            def batch = cnt % params.sage_processes
            // TODO hash the key to make it shorter?
            [groupkey, batch, metapart, mzml]
        }
        // group into chunks to be processed at the same time on the same node by sage
        // TODO I guess if we parametrize the nr of files per process, it is more
        //  efficient (because this process can start as soon as this number of files
        //  are available and does not need to wait and see how many Channel entries
        //  belong to batch X). But the problem is groupTuple(size:) cannot be
        //  specified with an output from a Channel. The only way would be to,
        //  IN THE VERY BEGINNING, parse
        //  the number of files (=lines?) in the SDRF/design (outside of a process),
        //  save this value and pass it along the pipeline.
        ch_meta_mzml_db_chunked = ch_meta_mzml_db.groupTuple(by: [0,1])

        SAGE(ch_meta_mzml_db_chunked.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(SAGE.out.versions)
        // we can safely use merge here since it is the same process
        ch_id_sage = ch_id_sage.mix(SAGE.out.id_files_sage.transpose())
    }

    emit:
    ch_id_files_idx = ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage)
    versions        = ch_versions
}
