//
//  Utility functions used in nf-core DSL2 module files
//

//
// Extract name of software tool from process name using $task.process
//
def getSoftwareName(task_process) {
    return task_process.tokenize(':')[-1].tokenize('_')[0].toLowerCase()
}

//
// Function to initialise default values and to generate a Groovy Map of available options for nf-core modules
//
def initOptions(Map args) {
    def Map options = [:]
    if (args.diss_meth == "HCD") options.diss_meth = "High-energy collision-induced dissociation"
    else if (args.diss_meth == "CID") options.diss_meth = "Collision-induced dissociation"
    else if (args.diss_meth == "ETD") options.diss_meth = "Electron transfer dissociation"
    else if (args.diss_meth == "ECD") options.diss_meth = "Electron capture dissociation"

    options.label                   = args.label ?: "tmt6plex"
    options.reporter_mass_shift     = args.reporter_mass_shift ?: 0.002
    options.min_reporter_intensity  = args.min_reporter_intensity ?: 0.0
    options.min_precursor_purity    = args.min_precursor_purity ?: 0.0
    options.precursor_isotope_deviation = args.precursor_isotope_deviation ?: 10.0
    options.iso_normalization       = args.iso_normalization ? "-quantification:normalization" : ""
    options.reference_channel       = args.reference_channel ?: 126
    options.iso_debug               = args.iso_debug ?: 100
    options.publish_by_meta         = args.publish_by_meta ?: []
    options.publish_dir             = args.publish_dir ?: ''
    options.publish_files           = args.publish_files
    options.suffix                  = args.suffix ?: ''
    return options
}

//
// Tidy up and join elements of a list to return a path string
//
def getPathFromList(path_list) {
    def paths = path_list.findAll { item -> !item?.trim().isEmpty() }      // Remove empty entries
    paths     = paths.collect { it.trim().replaceAll("^[/]+|[/]+\$", "") } // Trim whitespace and trailing slashes
    return paths.join('/')
}

//
// Function to save/publish module results
//
def saveFiles(Map args) {
    if (!args.filename.endsWith('.version.txt')) {
        def ioptions  = initOptions(args.options)
        def path_list = [ ioptions.publish_dir ?: args.publish_dir ]
        if (ioptions.publish_by_meta) {
            def key_list = ioptions.publish_by_meta instanceof List ? ioptions.publish_by_meta : args.publish_by_meta
            for (key in key_list) {
                if (args.meta && key instanceof String) {
                    def path = key
                    if (args.meta.containsKey(key)) {
                        path = args.meta[key] instanceof Boolean ? "${key}_${args.meta[key]}".toString() : args.meta[key]
                    }
                    path = path instanceof String ? path : ''
                    path_list.add(path)
                }
            }
        }
        if (ioptions.publish_files instanceof Map) {
            for (ext in ioptions.publish_files) {
                if (args.filename.endsWith(ext.key)) {
                    def ext_list = path_list.collect()
                    ext_list.add(ext.value)
                    return "${getPathFromList(ext_list)}/$args.filename"
                }
            }
        } else if (ioptions.publish_files == null) {
            return "${getPathFromList(path_list)}/$args.filename"
        }
    }
}
