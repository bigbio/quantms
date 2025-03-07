//
// Extract psm feature and ReScoring psm
//

include { EXTRACTPSMFEATURES             } from '../../modules/local/openms/extractpsmfeatures/main'
include { PERCOLATOR                     } from '../../modules/local/openms/thirdparty/percolator/main'
include { MS2RESCORE                     } from '../../modules/local/ms2rescore/main'
include { GETSAMPLE                      } from '../../modules/local/extract_sample/main'
include { IDMERGER                       } from '../../modules/local/openms/idmerger/main'
include { IDRIPPER                       } from '../../modules/local/openms/idripper/main'
include { SPECTRUM2FEATURES              } from '../../modules/local/spectrum2features/main'

workflow PSMRESCORING {
    take:
    ch_file_preparation_results
    ch_id_files
    ch_expdesign

    main:
    ch_software_versions = Channel.empty()
    ch_results  = Channel.empty()
    ch_fdridpep = Channel.empty()

    ch_id_files.branch{ meta, filename ->
        sage: filename.name.contains('sage')
            return [meta, filename]
        nosage: true
            return [meta, filename, []]
    }.set{ch_id_files_branched}

    if (params.ms2rescore == true) {
        MS2RESCORE(ch_id_files.combine(ch_file_preparation_results, by: 0))
        ch_software_versions = ch_software_versions.mix(MS2RESCORE.out.versions)
        ch_id_files_feats = MS2RESCORE.out.idxml
    } else {
        EXTRACTPSMFEATURES(ch_id_files_branched.nosage)
        ch_id_files_feats = ch_id_files_branched.sage.mix(EXTRACTPSMFEATURES.out.id_files_feat)
        ch_software_versions = ch_software_versions.mix(EXTRACTPSMFEATURES.out.versions)
    }

    // Add SNR features to percolator
    if (params.add_snr_feature_percolator) {
        SPECTRUM2FEATURES(ch_id_files_feats.combine(ch_file_preparation_results, by: 0))
        ch_id_files_feats = SPECTRUM2FEATURES.out.id_files_snr
        ch_software_versions = ch_software_versions.mix(SPECTRUM2FEATURES.out.versions)
    }

    // Rescoring for independent run, Sample or whole experiments
    if (params.rescore_range == "independent_run") {
        PERCOLATOR(ch_id_files_feats)
        ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
        ch_consensus_input = PERCOLATOR.out.id_files_perc
    } else if (params.rescore_range == "by_sample") {
        // Sample map
        GETSAMPLE(ch_expdesign)
        ch_software_versions = ch_software_versions.mix(GETSAMPLE.out.versions)
        ch_expdesign_sample = GETSAMPLE.out.ch_expdesign_sample
        ch_expdesign_sample.splitCsv(header: true, sep: '\t')
            .map { get_sample_map(it) }.set{ sample_map_idv }

        ch_id_files_feats.map {[it[0].mzml_id, it[0], it[1]]}.set { ch_id_files_feats}
        ch_id_files_feats.combine(sample_map_idv, by: 0).map {[it[1], it[2], it[3]]}.set{ch_id_files_feats}

        // Group by search_engines and convert meta
        ch_id_files_feats.branch{ meta, filename, sample  ->
            sage: filename.name.contains('sage')
                return [meta, filename, sample]
            msgf: filename.name.contains('msgf')
                return [meta, filename, sample]
            comet: filename.name.contains('comet')
                return [meta, filename, sample]
        }.set{ch_id_files_feat_branched}

        // IDMERGER for samples group
        IDMERGER(ch_id_files_feat_branched.comet.groupTuple(by: 2)
            .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 2))
            .mix(ch_id_files_feat_branched.sage.groupTuple(by: 2)))
        ch_software_versions = ch_software_versions.mix(IDMERGER.out.versions)

        PERCOLATOR(IDMERGER.out.id_merged)
        ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

        // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
        IDRIPPER(PERCOLATOR.out.id_files_perc)
        ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
        IDRIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
        meta.combine(id_rippers, by: 0)
                .map{ [it[1], it[2], "MS:1001491"]}
                .set{ ch_consensus_input }
        ch_software_versions = ch_software_versions.mix(IDRIPPER.out.versions)

    } else if (params.rescore_range == "by_project"){
        ch_id_files_feats.map {[it[0].experiment_id, it[0], it[1]]}.set { ch_id_files_feats}

        // Split ch_id_files_feats by search_engines
        ch_id_files_feats.branch{ experiment_id, meta, filename ->
            sage: filename.name.contains('sage')
                return [meta, filename, experiment_id]
            msgf: filename.name.contains('msgf')
                return [meta, filename, experiment_id]
            comet: filename.name.contains('comet')
                return [meta, filename, experiment_id]
        }.set{ch_id_files_feat_branched}

        // IDMERGER for whole experiments
        IDMERGER(ch_id_files_feat_branched.comet.groupTuple(by: 2)
            .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 2))
            .mix(ch_id_files_feat_branched.sage.groupTuple(by: 2)))
        ch_software_versions = ch_software_versions.mix(IDMERGER.out.versions)

        PERCOLATOR(IDMERGER.out.id_merged)
        ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

        // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
        IDRIPPER(PERCOLATOR.out.id_files_perc)
        ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
        IDRIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
        meta.combine(id_rippers, by: 0)
                .map{ [it[1], it[2], "MS:1001491"]}
                .set{ ch_consensus_input }
        ch_software_versions = ch_software_versions.mix(IDRIPPER.out.versions)
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

// Function to get sample map
def get_sample_map(LinkedHashMap row) {
    def sample_map = [:]

    filestr               = row.Spectra_Filepath
    file_name             = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))
    sample                = row.Sample

    return [file_name, sample]

}


