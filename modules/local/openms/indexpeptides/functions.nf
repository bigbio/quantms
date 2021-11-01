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
    // see comment in CometAdapter. Alternative here in PeptideIndexer is to let it auto-detect the enzyme by not specifying.
    if (args.search_engines.contains("msgf"))
    {
        if (args.enzyme == 'Trypsin') options.enzyme = 'Trypsin/P'
        else if (args.enzyme == 'Arg-C') options.enzyme = 'Arg-C/P'
        else if (args.enzyme == 'Asp-N') options.enzyme = 'Asp-N/B'
        else if (args.enzyme == 'Chymotrypsin') options.enzyme = 'Chymotrypsin/P'
        else if (args.enzyme == 'Lys-C') options.enzyme = 'Lys-C/P'
    }
    if (args.enzyme == "unspecific cleavage")
    {
        args.num_enzyme_termini = "none"
    }
    num_enzyme_termini = args.num_enzyme_termini
    if (args.num_enzyme_termini == "fully")
    {
        num_enzyme_termini = "full"
    }
    def il = args.IL_equivalent ? '-IL_equivalent' : ''
    def allow_um = args.allow_unmatched ? '-allow_unmatched' : ''

    options.num_enzyme_termini      = num_enzyme_termini
    options.il                      = il
    options.allow_um                = allow_um
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
