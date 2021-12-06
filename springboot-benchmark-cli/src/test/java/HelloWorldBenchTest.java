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
