/**
 * Define a function that removes adapter lines from samplesheets.
 *
 */

class AdapterRemover {

    public static String removeAdaptersFromSampleSheet(samplesheet) {
        def lines_out = ''
        def removal_checker = false
        samplesheet.readLines().each { line ->
            if ( line =~ /Adapter(Read[12])?,[ACGT]+,?/ ) {
                removal_checker = true
            } else {
                // keep original line otherwise
                lines_out = lines_out + line + '\n'
            }
        }
        if (!removal_checker) {
            System.out.println("\u001B[94m[INFO] Parameter `remove_samplesheet_adapter` was set to true but no adapters were found in samplesheet\u001B[0m")
        }
        return lines_out
    }
}
