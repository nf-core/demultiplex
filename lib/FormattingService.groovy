// lib/FormattingService.groovy
import static groovy.json.JsonOutput.prettyPrint
import groovy.json.JsonGenerator
import java.nio.file.Path
import java.time.OffsetDateTime
import nextflow.util.Duration

/**
 * Define a service that formats objects for printing.
 */
class FormattingService {

    /**
     * Define a JSON generator with appropriate converters for problematic types.
     */
    protected static JsonGenerator generator = new JsonGenerator.Options()
        .dateFormat("yyyy-MM-dd'T'HH:mm:ssXXX")
        .addConverter(OffsetDateTime) { OffsetDateTime offset -> offset.toString() }
        .addConverter(Duration) { Duration duration -> duration.toString() }
        .addConverter(Path) { Path filename -> filename.toString() }
        .build()

    /**
     * Create a pretty string format of a given object using JSON.
     *
     * @param object The given object (typically a map) that is to be represented as a
     *     JSON-like pretty string.
     * @return A JSON string.
     */
    static String prettyFormat(Object object) {
        return prettyPrint(generator.toJson(object))
    }
}