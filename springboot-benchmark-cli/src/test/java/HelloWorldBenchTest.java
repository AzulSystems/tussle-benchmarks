/*
 * Copyright (c) 2021, Azul Systems
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

import static org.junit.Assert.fail;

import org.benchmarks.BenchmarkConfig;
import org.benchmarks.httpclient.HttpClientBenchmark;
import org.junit.Test;

import static org.benchmarks.tools.FormatTool.*;

public class HelloWorldBenchTest {

    static final String SLAs = "[[50, 1, 10000], [90, 2, 20000], [99, 10, 30000]]";

    static final String benchArgs1[] = {
            "-s",
            "histogramsDir: results1/histograms\n" +
            "reportDir: results1/report\n" +
            "slaConfig: " + SLAs + "\n" +
            "startingWarmupTime: 10\n" +
            "warmupTime: 2\n" +
            "time: 10\n" +
            "threads: 4\n" +
            "highBound: 10000\n" +
            "startingRatePercent: 50\n" +
            "finishingRatePercent: 100\n" +
            "retriesMax: 0\n" +
            "ratePercentStep: 50\n"
    };

    static final String benchArgs2[] = {
            "-s",
            "histogramsDir: results/histograms\n" +
            "reportDir: results/report\n" +
            "slaConfig: " + SLAs + "\n" +
            "startingWarmupTime: 60\n" +
            "warmupTime: 20\n" +
            "time: 40\n" +
            "threads: 4\n" +
            "highBound: 10000\n" +
            "startingRatePercent: 20\n" +
            "finishingRatePercent: 110\n" +
            "retriesMax: 2\n" +
            "ratePercentStep: 5\n"
    };

    @Test
    public void testHttpCLient() {
        HttpClientBenchmark b = new HttpClientBenchmark();
        try {
            b.init(benchArgs1);
            BenchmarkConfig c = b.getConfig();
            b.run(parseValue(c.getTargetRate()), parseTimeLength(c.getWarmupTime()), parseTimeLength(c.getRunTime()), null);
        } catch (Exception e) {
            e.printStackTrace();
            fail("failed");
        }
    }
}
