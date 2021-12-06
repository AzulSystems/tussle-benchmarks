package org.benchmarks.springboot;

import java.util.Arrays;

import org.benchmarks.BasicRunner;
import org.benchmarks.tools.LoggerTool;

public class HelloWorldBenchRunner {
    public static void main(String[] args) {
        if (args.length > 0 && (args[0].equals("-server") || args[0].equals("--server"))) {
            args = Arrays.copyOfRange(args, 1, args.length);
            HelloWorldApp.main(args);
        } else {
            LoggerTool.init("benchmark");
            new BasicRunner().run(HelloWorldBench.class, args);
        }
    }
}
