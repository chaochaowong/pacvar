workflow ANNOTSV_CACHE_INITIALISATION {
    take:
    annotsv_cache   // path
    annotsv_genome  // string
    annotsv_enabled // boolean

    main:

    ch_annotsv_cache = channel.empty()
    // Only run checks if AnnotSV is not skipped
    if (annotsv_enabled) {
        // 1. Check Genome Assembly
        def allowed_genomes = ['CHM13', 'GRCh37', 'GRCh38']
        if (!allowed_genomes.contains(annotsv_genome)) {
            error "[AnnotSV Error] Genome '${annotsv_genome}' is not supported. Please use GRCh37, GRCh38, CHM13."
        }

        // 2. Check Cache Existence
        if (!annotsv_cache) {
            error "[AnnotSV Error] AnnotSV is enabled but 'annotsv_cache' is null. Please provide a path."
        }
        
        def cache_path = file(annotsv_cache)
        if (!cache_path.exists()) {
            error "[AnnotSV Error] The provided AnnotSV cache path does not exist: ${annotsv_cache}"
        }

        // 3. cloud specific check
        if (isCloudUrl(annotsv_cache) && cache_path.isEmpty()) {
            error "[AnnotSV Error] cloud bucket/path is empty or unreachable: ${annotsv_cache}"
        }

        // 4. Check for the mandatory "AnnotSV_annotations" subdirectory
        // We look specifically for path/to/cache/AnnotSV_annotations
        def sub_dir = file("${annotsv_cache}/AnnotSV_annotations")
        if (!sub_dir.exists() || !sub_dir.isDirectory()) {
            error "[AnnotSV Error] The cache directory exists, but it is missing the required 'AnnotSV_annotations' subdirectory at: ${sub_dir}"
        }

        ch_annotsv_cache = channel.fromPath("${annotsv_cache}/AnnotSV_annotations", type: 'dir', checkIfExists: true)
            .collect()
            .map { dir -> [[id: "${annotsv_genome}"], dir] }
    }


    emit:
    annotsv_cache = ch_annotsv_cache // channel: [meta, cache]
}

// Helper function to check if cache path is from any cloud provider
def isCloudUrl(cache_url) {
    return cache_url.startsWith("s3://") || cache_url.startsWith("gs://") || cache_url.startsWith("az://")
}