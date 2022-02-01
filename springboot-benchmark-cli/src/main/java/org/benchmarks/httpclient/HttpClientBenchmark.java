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
