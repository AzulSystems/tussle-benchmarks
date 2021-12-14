package org.benchmarks.httpclient;

import java.net.URI;

import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.benchmarks.RunnableWithError;
import org.benchmarks.WlBenchmark;
import org.benchmarks.WlConfig;

public class HttpClientBenchmark extends WlBenchmark {

    private CloseableHttpClient httpClient;
    private URI targetURI;
    private int expectedHttpCode;

    @Override
    public void init(String[] args) throws Exception {
        super.init(args);
        httpClient = HttpClientBuilder.create().build();
        HttpClientBenchmarkConfig config = (HttpClientBenchmarkConfig) this.config;
        targetURI = URI.create(config.targetURI);
        expectedHttpCode = config.expectedHttpCode;
    }

    @Override
    public String getOperationName() {
        return "http_get";
    }

    @Override
    public RunnableWithError getWorkload() {
        return () -> {
            boolean success = false;
            final HttpGet request = new HttpGet(targetURI);
            try (CloseableHttpResponse httpResponse = httpClient.execute(request)) {
                request.reset();
                if (httpResponse.getStatusLine().getStatusCode() == expectedHttpCode) {
                    success = true;
                }
            } catch (Exception e) {
            }
            return success;
        };
    }

    @Override
    public Class<? extends WlConfig> getConfigClass() {
        return HttpClientBenchmarkConfig.class;
    }

    @Override
    public void cleanup() {
        if (httpClient != null) {
            try {
                log("Closing httpClient...");
                httpClient.close();
            } catch (Exception e) {
            }
            httpClient = null;
        }
    }
}
