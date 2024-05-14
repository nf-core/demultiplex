/**
 * MIT License
 *
 * Copyright (c) 2022 Moritz E. Beber
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import static groovy.json.JsonOutput.prettyPrint
import groovy.json.JsonGenerator
import java.nio.file.Path
import java.time.OffsetDateTime
import nextflow.util.Duration

/**
 * Define a service that formats objects for printing.
 *
 * @author Moritz E. Beber
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
