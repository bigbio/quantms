//
// This file holds several functions specific to the main.nf workflow in the nf-core/quantms pipeline
//

import nextflow.Nextflow

class WorkflowMain {

    //
    // Citation string for pipeline
    //
    public static String citation(workflow) {
        return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
            // TODO nf-core: Add Zenodo DOI for pipeline after first release
            //"* The pipeline\n" +
            //"  https://doi.org/10.5281/zenodo.XXXXXXX\n\n" +
            "* The nf-core framework\n" +
            "  https://doi.org/10.1038/s41587-020-0439-x\n\n" +
            "* Software dependencies\n" +
            "  https://github.com/${workflow.manifest.name}/blob/master/CITATIONS.md"
    }


    //
    // Validate parameters and print summary to screen
    //
    public static void initialise(workflow, params, log) {

        // Print workflow version and exit on --version
        if (params.version) {
            String workflow_version = NfcoreTemplate.version(workflow)
            log.info "${workflow.manifest.name} ${workflow_version}"
            System.exit(0)
        }

        // Check that a -profile or Nextflow config has been provided to run the pipeline
        NfcoreTemplate.checkConfigProvided(workflow, log)

        // Check that conda channels are set-up correctly
        if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
            Utils.checkCondaChannels(log)
        }

        // Check AWS batch settings
        NfcoreTemplate.awsBatch(workflow, params)

        // Check input has been provided
        if (!params.input) {
            Nextflow.error("Please provide an input sdrf to the pipeline e.g. '--input *.sdrf.csv'")
        }

        // Check input has been provided
        if (!params.outdir) {
            log.error "Please provide an outdir to the pipeline e.g. '--outdir ./results'"
            System.exit(1)
        }

        if (params.tracedir == "null/pipeline_info")
        {
            Nextflow.error("""Error: Your tracedir is `null/pipeline_info`, this means you probably set outdir in a way that does not affect the default
            `\$params.outdir/pipeline_info` (e.g., by specifying outdir in a profile instead of the commandline or through a `-params-file`.
            Either set outdir in a correct way, or redefine tracedir as well (e.g., in your profile).""")
        }

        // check fasta database has been provided
        if (!params.database) {
            Nextflow.error("Please provide an fasta database to the pipeline e.g. '--database *.fasta'")
    }
    }
}
