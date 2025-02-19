// Function to verify paths in downstream samplesheets

import java.nio.file.*


class UTILS{
    public static boolean validateFastqPaths(Object csvFilePath) {
        String path = csvFilePath.toString()  // Convert GString or any other type to String
        def csvFile = new File(path)

        if (!csvFile.exists()) {
            throw new FileNotFoundException("CSV file not found at: $path")
        }

        // Define allowed column names
        def allowedColumns = ["sample", "fastq_1", "fastq_2", "strandedness", "replicate", "fasta", "genome", "patient", "lane"]

        csvFile.withReader { reader ->
            // Read the header and trim quotes
            def header = reader.readLine().split(",").collect { it.replaceAll('"', '').trim() }
            def fastq1Index = header.indexOf("fastq_1")
            def fastq2Index = header.indexOf("fastq_2")

            // Check for the presence of 'fastq_1' column
            if (fastq1Index == -1) {
                throw new IllegalArgumentException("CSV file '$csvFile.name' does not contain a 'fastq_1' column.")
            }

            // Check for valid column names
            header.each { column ->
                if (!allowedColumns.contains(column)) {
                    throw new IllegalArgumentException("Invalid column name: '$column' in downstream samplesheet file '$csvFile.name'. Allowed columns are: ${allowedColumns.join(', ')}.")
                }
            }

            reader.eachLine { line ->
                def columns = line.split(",").collect { it.replaceAll('"', '').trim() }
                def fastq1Path = columns[fastq1Index]
                def fastq2Path = fastq2Index != -1 ? columns[fastq2Index] : null  // Use null if fastq_2 is not present

                // Check if fastq_1 path is valid
                if (!Files.exists(Paths.get(fastq1Path))) {
                    throw new FileNotFoundException("Incorrect R1 fastq file path: '$fastq1Path' in downstream samplesheet file '$csvFile.name'") // Raise error for fastq_1
                }

                // Check if fastq_2 path is valid if it exists
                if (fastq2Path && !Files.exists(Paths.get(fastq2Path))) {
                    throw new FileNotFoundException("Incorrect R2 fastq file path: '$fastq2Path' in downstream samplesheet file '$csvFile.name'") // Raise error for fastq_2
                }
            }
        }
        return true // All paths are valid if we reach this point
    }
}
