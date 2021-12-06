package org.benchmarks.springboot;

import org.benchmarks.httpclient.HttpClientBenchmark;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;

public class HelloWorldBench extends HttpClientBenchmark {

    private static final java.util.logging.Logger log = java.util.logging.Logger.getGlobal();

    private ConfigurableApplicationContext applicationContext;

    @Override
    public void init(String[] args) throws Exception {
        super.init(args);
        applicationContext = SpringApplication.run(HelloWorldApp.class);
    }

    @Override
    public void cleanup() {
        super.cleanup();
        if (applicationContext != null) {
            log.info("Closing Springboot app...");
            applicationContext.close();
            applicationContext = null;
        }
    }
}
