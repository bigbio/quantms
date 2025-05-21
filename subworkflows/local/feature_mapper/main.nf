//
// Assigns protein/peptide identifications to features or consensus features.
//

include { ISOBARIC_ANALYZER } from '../../../modules/local/openms/isobaric_analyzer/main'
include { ID_MAPPER         } from '../../../modules/local/openms/id_mapper/main'

workflow FEATURE_MAPPER {
    take:
    ch_mzml_files
    ch_id_files

    main:
    ch_version = Channel.empty()

    ISOBARIC_ANALYZER(ch_mzml_files)
    ch_version = ch_version.mix(ISOBARIC_ANALYZER.out.versions)

    ID_MAPPER(ch_id_files.combine(ISOBARIC_ANALYZER.out.id_files_consensusXML, by: 0))
    ch_version = ch_version.mix(ID_MAPPER.out.versions)

    emit:
    id_map  = ID_MAPPER.out.id_map

    versions = ch_version
}
