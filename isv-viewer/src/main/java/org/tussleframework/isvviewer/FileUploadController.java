/*
 * Copyright (c) 2021-2023, Azul Systems
 * 
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 * 
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * 
 * * Neither the name of [project] nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */

package org.tussleframework.isvviewer;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import org.HdrHistogram.AbstractHistogram;
import org.HdrHistogram.EncodableHistogram;
import org.HdrHistogram.Histogram;
import org.HdrHistogram.HistogramIterationValue;
import org.HdrHistogram.HistogramLogReader;
import org.HdrHistogram.PercentileIterator;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;

class HiccupData {
    public final List<Double> latencies = new ArrayList<>();
    public final List<Double> percentileLevels = new ArrayList<>();
    public final List<Double> percentileValues = new ArrayList<>();

    public HiccupData(InputStream is) {
        Histogram histogram = new Histogram(5);
        HistogramLogReader hdrReader = new HistogramLogReader(is);
        while (true) {
            final EncodableHistogram interval = hdrReader.nextIntervalHistogram(0, Double.MAX_VALUE);
            if (interval == null) {
                break;
            }
            latencies.add(interval.getMaxValueAsDouble() / 1E6D);
            histogram.add((AbstractHistogram) interval);
        }
        PercentileIterator percentileIterator = new PercentileIterator(histogram, 5);
        while (percentileIterator.hasNext()) {
            HistogramIterationValue value = percentileIterator.next();
            final double percentileLevel = value.getPercentileLevelIteratedTo();
            if (Double.isInfinite(percentileLevel))
                break;
            percentileLevels.add(percentileLevel);
            percentileValues.add(value.getDoubleValueIteratedTo() / 1E6D);
        }
    }
}

@Controller
public class FileUploadController {
    
    private final Log log = LogFactory.getLog(getClass());

    @PostMapping(path = "/hiccup", produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseBody( )
    public HiccupData handleHiccupFile(@RequestParam("file") MultipartFile file) throws IOException {
        log.info("handleFileUpload: " + file.getName() + " - " + file.getOriginalFilename() + " size: " + file.getSize() + " " + file.getContentType());
        return new HiccupData(file.getInputStream());
    }
}
