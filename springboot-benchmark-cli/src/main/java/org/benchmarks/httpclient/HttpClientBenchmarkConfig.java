package org.benchmarks.httpclient;

import org.benchmarks.WlConfig;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;

@Data
@ToString(callSuper = true)
@EqualsAndHashCode(callSuper = true)
public class HttpClientBenchmarkConfig extends WlConfig {
    public String targetURI = "http://localhost:8080";
    public int expectedHttpCode = 200;
}
