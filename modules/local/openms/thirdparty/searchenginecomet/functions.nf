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
    if (args.frag_tol_unit == "ppm") {
        // Note: This uses an arbitrary rule to decide if it was hi-res or low-res
        // and uses Comet's defaults for bin size, in case unsupported unit "ppm" was given.
        if (args.frag_tol.toDouble() < 50) {
            options.bin_tol = "0.015"
            options.bin_offset = "0.0"
            options.inst = args.instrument ?: "high_res"
        } else {
            options.bin_tol = "0.50025"
            options.bin_offset = "0.4"
            options.inst = args.instrument ?: "low_res"
        }
        log.warn "The chosen search engine Comet does not support ppm fragment tolerances. We guessed a " + inst +
            " instrument and set the fragment_bin_tolerance to " + bin_tol
    } else {
        options.bin_tol = args.frag_tol.toDouble() / 2.0
        options.bin_offset = args.frag_tol.toDouble() < 0.1 ? "0.0" : "0.4"
        if (!args.instrument)
        {
            options.inst = args.frag_tol.toDouble() < 0.1 ? "high_res" : "low_res"
        } else {
            options.inst = args.instrument
        }
    }

    if args.search_engines.contains("msgf")){
        if (args.enzyme == "Trypsin") options.enzyme = "Trypsin/P"
        else if (args.enzyme == "Arg-C") options.enzyme = "Arg-C/P"
        else if (args.enzyme == "Asp-N") options.enzyme = "Arg-N/B"
        else if (args.enzyme == "Chymotrypsin") options.enzyme = "Chymotrypsin/P"
        else if (args.enzyme == "Lys-C") options.enzyme = "Lys-C/P"
    }

    // converting isotope_error_range from MSGF style to Comet style. Compatibility is checked in the
    // beginning.
    def isoSlashComet = "0/1"
    if (args.isotope_error_range)
    {
        def isoRangeComet = args.isotope_error_range.split(",")
        isoSlashComet = ""
        for (c in isoRangeComet[0].toInteger()..isoRangeComet[1].toInteger()-1)
        {
            isoSlashComet += c + "/"
        }
            isoSlashComet += isoRangeComet[1]
        }
    options.isoSlashComet           = isoSlashComet

    options.allowed_missed_cleavages = args.allowed_missed_cleavages ?: 2
    options.num_hits                = args.num_hits ?: 1
    options.num_enzyme_termini      = args.num_enzyme_termini ?: "fully"
    options.min_precursor_charge    = args.min_precursor_charge ?: 2
    options.max_precursor_charge    = args.max_precursor_charge ?: 3
    options.fixed                   = args.fixed ?: "Carbamidomethyl (C)"
    options.variable                = args.variable ?: "Oxidation (M)"
    options.max_mods                = args.max_mods ?: 3
    options.min_peptide_length      = args.min_peptide_length ?: 6
    options.max_peptide_length      = args.max_peptide_length ?: 40
    options.prec_tol                = args.prec_tol ?: 10
    options.prec_tol_unit           = args.prec_tol_unit ?: "ppm"
    options.db_debug                = args.db_debug ?: 0
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
