//
// Extract psm feature and ReScoring psm
//

include { PERCOLATOR              } from '../../../modules/local/openms/percolator/main'

include { ID_RIPPER               } from '../../../modules/local/openms/id_ripper/main'


workflow PSM_RESCORING {
    take:
    ch_file_preparation_results
    ch_id_files_feats
    ch_expdesign

    main:
    ch_software_versions = Channel.empty()
    ch_results  = Channel.empty()
    ch_fdridpep = Channel.empty()

    // Rescoring for independent run, Sample or whole experiments
    if (params.ms2features_range == "independent_run") {
        PERCOLATOR(ch_id_files_feats)
        ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
        ch_consensus_input = PERCOLATOR.out.id_files_perc
    } else if (params.ms2features_range == "by_sample") {
        PERCOLATOR(ch_id_files_feats)
        ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

        // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
        ID_RIPPER(PERCOLATOR.out.id_files_perc)
        ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
        ID_RIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
        meta.combine(id_rippers, by: 0)
                .map{ [it[1], it[2]]}
                .set{ ch_consensus_input }
        ch_software_versions = ch_software_versions.mix(ID_RIPPER.out.versions)

    } else if (params.ms2features_range == "by_project"){
        PERCOLATOR(ch_id_files_feats)
        ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

        // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
        ID_RIPPER(PERCOLATOR.out.id_files_perc)
        ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
        ID_RIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
        meta.combine(id_rippers, by: 0)
                .map{ [it[1], it[2]]}
                .set{ ch_consensus_input }
        ch_software_versions = ch_software_versions.mix(ID_RIPPER.out.versions)
    }
    ch_rescoring_results = ch_consensus_input

    emit:
    results = ch_rescoring_results
    versions = ch_software_versions
}

def add_file_prefix(file_path) {
    position = file(file_path).name.lastIndexOf('_sage_perc.idXML')
    if (position == -1) {
        position = file(file_path).name.lastIndexOf('_comet_perc.idXML')
        if (position == -1) {
            position = file(file_path).name.lastIndexOf('_msgf_perc.idXML')
        }
    }
    file_name = file(file_name).name.take(position)
    return [file_name, file_path]
}
