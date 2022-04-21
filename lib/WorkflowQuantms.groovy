//
// This file holds several functions specific to the workflow/quantms.nf in the nf-core/quantms pipeline
//

class WorkflowQuantms {

    //
    // Check and validate parameters
    //
    public static void initialise(params, log) {
        if (!params.database) {
            log.error "database file not specified with e.g. '--database *.fasta' or via a detectable config file."
            System.exit(1)
        }
    }

    //
    // Get workflow summary for MultiQC
    //
    public static String paramsSummaryMultiqc(workflow, summary) {
        String summary_section = ''
        for (group in summary.keySet()) {
            def group_params = summary.get(group)  // This gets the parameters of that particular group
            if (group_params) {
                summary_section += "    <p style=\"font-size:110%\"><b>$group</b></p>\n"
                summary_section += "    <dl class=\"dl-horizontal\">\n"
                for (param in group_params.keySet()) {
                    summary_section += "        <dt>$param</dt><dd><samp>${group_params.get(param) ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>\n"
                }
                summary_section += "    </dl>\n"
            }
        }

        String yaml_file_text  = "id: '${workflow.manifest.name.replace('/','-')}-summary'\n"
        yaml_file_text        += "description: ' - this information is collected when the pipeline is started.'\n"
        yaml_file_text        += "section_name: '${workflow.manifest.name} Workflow Summary'\n"
        yaml_file_text        += "section_href: 'https://github.com/${workflow.manifest.name}'\n"
        yaml_file_text        += "plot_type: 'html'\n"
        yaml_file_text        += "data: |\n"
        yaml_file_text        += "${summary_section}"
        return yaml_file_text
    }

    //
    // Check class of an Object for "List" type
    //
    public static boolean isCollectionOrArray(object) {
        return  [Collection, Object[]].any { it.isAssignableFrom(object.getClass()) }
        }

    //
    // check file extension
    //
    public static boolean hasExtension(file, extension) {
        return file.toString().toLowerCase().endsWith(extension.toLowerCase())
    }
}
