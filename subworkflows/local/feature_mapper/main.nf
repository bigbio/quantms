//
// Assigns protein/peptide identifications to features or consensus features.
//

include { ISOBARIC_ANALYZER } from '../../modules/local/openms/isobaric_analyzer/main'
include { ID_MAPPER         } from '../../modules/local/openms/id_mapper/main'

workflow FEATURE_MAPPER {
    take:
    ch_mzml_files
    ch_id_files

    main:
    ch_version = Channel.empty()

    ISOBARICANALYZER(ch_mzml_files)
    ch_version = ch_version.mix(ISOBARICANALYZER.out.versions)

    IDMAPPER(ch_id_files.combine(ISOBARICANALYZER.out.id_files_consensusXML, by: 0))
    ch_version = ch_version.mix(IDMAPPER.out.versions)

    emit:
    id_map  = IDMAPPER.out.id_map

    versions = ch_version
}
