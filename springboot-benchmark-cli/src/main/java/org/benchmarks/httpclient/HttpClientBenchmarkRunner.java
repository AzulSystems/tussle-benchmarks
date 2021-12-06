package org.benchmarks.httpclient;

import org.benchmarks.BasicRunner;
import org.benchmarks.tools.LoggerTool;

public class HttpClientBenchmarkRunner {
    public static void main(String[] args) {
        LoggerTool.init("benchmark");
        new BasicRunner().run(HttpClientBenchmark.class, args);
   }
}
