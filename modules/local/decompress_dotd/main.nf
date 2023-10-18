
process DECOMPRESS {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'error_retry'

    conda "conda-forge::gzip=1.12,conda-forge::tar=1.34,conda-forge::bzip2=1.0.8,conda-forge::unzip=6.0,conda-forge::xz=5.2.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-796b0610595ad1995b121d0b85375902097b78d4:a3a3220eb9ee55710d743438b2ab9092867c98c6-0' :
        'quay.io/biocontainers/mulled-v2-796b0610595ad1995b121d0b85375902097b78d4:a3a3220eb9ee55710d743438b2ab9092867c98c6-0' }"

    stageInMode {
        if (task.attempt == 1) {
            if (executor == 'awsbatch') {
                'symlink'
            } else {
                'link'
            }
        } else if (task.attempt == 2) {
            if (executor == 'awsbatch') {
                'copy'
            } else {
                'symlink'
            }
        } else {
            'copy'
        }
    }

    input:
    tuple val(meta), path(compressed_file)

    output:
    tuple val(meta), path('*.d'),   emit: decompressed_files
    path 'versions.yml',   emit: version
    path '*.log',   emit: log

    script:
    String prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    function extract {
        if [ -z "\$1" ]; then
            echo "Usage: extract <path/file_name>.<gz|tar|tar.bz2>"
        else
            if [ -f \$1 ]; then
                case \$1 in
                    *.tar.gz)    tar xvzf \$1    ;;
                    *.gz)        gunzip \$1      ;;
                    *.tar)       tar xvf \$1     ;;
                    *.zip)       unzip \$1     ;;
                    *)           echo "extract: '\$1' - unknown archive method" ;;
                esac
            else
                echo "\$1 - file does not exist"
            fi
        fi
    }

    tar --help 2>&1 | tee -a ${prefix}_decompression.log
    gunzip --help 2>&1 | tee -a ${prefix}_decompression.log
    unzip --help 2>&1 | tee -a ${prefix}_decompression.log
    echo "Unpacking..." | tee -a ${compressed_file.baseName}_decompression.log

    extract ${compressed_file} 2>&1 | tee -a ${compressed_file.baseName}_conversion.log
    [ -d ${file(compressed_file.baseName).baseName}.d ] && \\
        echo "Found ${file(compressed_file.baseName).baseName}.d" || \\
        mv *.d ${file(compressed_file.baseName).baseName}.d

    ls -l | tee -a ${compressed_file.baseName}_decompression.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(gunzip --help 2>&1 | head -1 | grep -oE "\\d+\\.\\d+(\\.\\d+)?")
        tar: \$(tar --help 2>&1 | head -1 | grep -oE "\\d+\\.\\d+(\\.\\d+)?")
        unzip: \$(unzip --help | head -2 | tail -1 | grep -oE "\\d+\\.\\d+")
    END_VERSIONS
    """
}
