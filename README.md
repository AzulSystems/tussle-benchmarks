# Tussle benchmarks & tools

### This repository contains bunch of benchmark and tools projects.
1. [Tussle Framework](#tussle-framework)
2. [Kafka benchmark](#kafka)
3. [Cassandra benchmark](#cassandra)
4. [HTTP client benchmark](#http)
5. [Springboot benchmark](#springboot)
6. [IO benchmark](#io)
7. [SQL benchmark](#sql)
8. [ISV viewer](#isv-viewer)

## Tussle Framework <a name="tussle-framework"/>

Tussle Framework is a separate project which includes common set of benchmark runners, metrics, result processors, reporter, and etc.:
https://github.com/AzulSystems/tussle-framework

## Kafka benchmark <a name="kafka"/>

Available as separate project:
https://github.com/AzulSystems/kafka-benchmark

## Cassandra benchmark <a name="cassandra"/>
Project location: [cassandra-benchmark](cassandra-benchmark)
Build:
```
$ cd cassandra-benchmark/
$ mvn clean package -DskipTests
```
Usage
```
$ java -jar target/cassandra-benchmark-*.jar  [...benchmark-args]  [--runner {tussle-benchmark-runner}  [{...runner-args}]]
```
Run:
```
# Test locally running Cassandra using default benchmark parameters (1 minute basic runner, etc.)
$ java -jar target/cassandra-benchmark-*.jar 
```
Results:
```
benchmark.log - benchmark output file
histograms - directory containing collected result histograms which can be processed and visualized using corresponding tool from the Tussle Framework
```
Output:
```
2023-05-22 15:06:40,023,NOVT [BasicRunner] Benchmark config: !!org.tussleframework.benchmark.CassandraBenchmarkConfig
host: localhost
...
2023-05-22 15:06:40,073,NOVT [BasicRunner] =================================================================== 
2023-05-22 15:06:40,074,NOVT [BasicRunner] Run once: cassandra-tussle (step 1) started 
2023-05-22 15:06:40,075,NOVT [BasicRunner] Benchmark reset... 
2023-05-22 15:06:40,394,NOVT [BasicRunner] Benchmark run at target rate 1000 op/s (100%), warmup 0 s, run time 60 s... 
2023-05-22 15:06:40,409,NOVT [TargetRunnerST] Starting: target rate 1000 op/s, time 60000 ms... 
2023-05-22 15:06:45,409,NOVT [HdrWriter] -------------------------------------------------------------------------------------------------------------------------- 
2023-05-22 15:06:45,411,NOVT [HdrWriter]           name |   time |  progr |    p50ms |    p90ms |    p99ms |   p100ms |     mean |    count |     rate |    total 
2023-05-22 15:06:45,411,NOVT [HdrWriter] -------------------------------------------------------------------------------------------------------------------------- 
2023-05-22 15:06:45,419,NOVT [HdrWriter]     write resp |      5 |   8.3% |    0.473 |    38.37 |    85.38 |    88.06 |    8.261 |     4998 |      999 |     4998 
2023-05-22 15:06:45,422,NOVT [HdrWriter]     write serv |      5 |   8.4% |     0.45 |    0.907 |    1.919 |    10.15 |   0.5556 |     5009 |      999 |     5009 
...
2023-05-22 15:07:40,410,NOVT [HdrWriter]     write serv |     60 | 100.0% |    0.391 |    0.644 |    1.035 |    5.855 |   0.4264 |     4998 |     1000 |    59998 
2023-05-22 15:07:40,413,NOVT [HdrWriter]     write resp |     60 | 100.0% |    0.413 |    0.684 |     1.25 |    5.863 |   0.4571 |     5002 |     1000 |    60000 
2023-05-22 15:07:41,412,NOVT [TargetRunnerST] Result: RunResult(rateUnits=op/s, timeUnits=ms, actualRate=1000.0, errors=0, count=60000, time=60000) 
2023-05-22 15:07:41,416,NOVT [BasicRunner] Reguested rate 1000 op/s (100%) , actual rate 1000 op/s 
2023-05-22 15:07:41,417,NOVT [BasicRunner] ----------------------------------------------------- 
2023-05-22 15:07:41,417,NOVT [BasicRunner] Run once: cassandra-tussle (step 1) finished 
2023-05-22 15:07:41,417,NOVT [BasicRunner] Results (step 1) 
2023-05-22 15:07:41,418,NOVT [BasicRunner] Count: 60000 
2023-05-22 15:07:41,419,NOVT [BasicRunner] Time: 60 s 
2023-05-22 15:07:41,419,NOVT [BasicRunner] Rate: 1000 op/s 
2023-05-22 15:07:41,420,NOVT [BasicRunner] Errors: 0 
2023-05-22 15:07:41,421,NOVT [BasicRunner] write response_time time: 60 s 
2023-05-22 15:07:41,422,NOVT [BasicRunner] write response_time p0: 0.13 ms 
2023-05-22 15:07:41,423,NOVT [BasicRunner] write response_time p50: 0.419 ms 
2023-05-22 15:07:41,423,NOVT [BasicRunner] write response_time p90: 0.733 ms 
2023-05-22 15:07:41,424,NOVT [BasicRunner] write response_time p99: 26.27 ms 
2023-05-22 15:07:41,424,NOVT [BasicRunner] write response_time p99.9: 84.86 ms 
2023-05-22 15:07:41,425,NOVT [BasicRunner] write response_time p99.99: 87.68 ms 
2023-05-22 15:07:41,426,NOVT [BasicRunner] write response_time p100: 88.06 ms 
2023-05-22 15:07:41,428,NOVT [BasicRunner] write response_time mean: 1.164 ms 
2023-05-22 15:07:41,429,NOVT [BasicRunner] write response_time rate: 1000 op/s 
...
```

## HTTP client benchmark <a name="http"/>
Project location: [httpclient-benchmark](httpclient-benchmark)
Build:
```
$ cd io-benchmark/
$ mvn clean package -DskipTests
```
Usage
```
$ java -jar target/httpclient-benchmark-*.jar  [...benchmark-args]  [--runner {tussle-benchmark-runner}  [{...runner-args}]]
```
Run:
```
$ java -jar target/httpclient-benchmark-*.jar
```
Results:
```
benchmark.log - benchmark output file
histograms - directory containing collected result histograms which can be processed and visualized using corresponding tool from the Tussle Framework
```
Output:
```
```

## Springboot benchmark <a name="springboot"/>
Project location: [springboot-benchmark-app](springboot-benchmark-app)

## IO benchmark <a name="io"/>
Project location: [io-benchmark](io-benchmark)
Build:
```
$ cd io-benchmark/
$ mvn clean package -DskipTests
```
Usage
```
$ java -jar target/io-benchmark-*.jar  [...benchmark-args]  [--runner {tussle-benchmark-runner}  [{...runner-args}]]
```
Run:
```
$ java -jar target/io-benchmark-*.jar
```
Results:
```
benchmark.log - benchmark output file
histograms - directory containing collected result histograms which can be processed and visualized using corresponding tool from the Tussle Framework
```
Output:
```
2023-05-22 19:59:57,892,NOVT [org.tussleframework.benchmark.IOBenchmark] Creating 1 large file... 
2023-05-22 19:59:59,677,NOVT [BasicRunner] Benchmark config: !!org.tussleframework.benchmark.IOBenchmarkConfig {async: false, filesDir: test_files,
  flush: true, largeCount: 1, largeSize: 1024, name: '', rateUnits: op/s, runName: '',
  smallSize: 10, threads: 1, timeUnits: ms} 
2023-05-22 19:59:59,692,NOVT [BasicRunner] Runner config: !!org.tussleframework.runners.BasicRunnerConfig
...
2023-05-22 19:59:59,699,NOVT [BasicRunner] =================================================================== 
2023-05-22 19:59:59,700,NOVT [BasicRunner] Run once: io-tussle (step 1) started 
2023-05-22 19:59:59,700,NOVT [BasicRunner] Benchmark reset... 
2023-05-22 19:59:59,702,NOVT [BasicRunner] Benchmark run at target rate 1000 op/s (100%), warmup 0 s, run time 60 s... 
2023-05-22 19:59:59,720,NOVT [TargetRunnerST] Starting: target rate 1000 op/s, time 60000 ms... 
2023-05-22 20:00:04,724,NOVT [HdrWriter] -------------------------------------------------------------------------------------------------------------------------- 
2023-05-22 20:00:04,727,NOVT [HdrWriter]           name |   time |  progr |    p50ms |    p90ms |    p99ms |   p100ms |     mean |    count |     rate |    total 
2023-05-22 20:00:04,728,NOVT [HdrWriter] -------------------------------------------------------------------------------------------------------------------------- 
2023-05-22 20:00:04,746,NOVT [HdrWriter]     force resp |      5 |   8.3% |      562 |      930 |      999 |     1071 |      548 |     3924 |      784 |     3924 
2023-05-22 20:00:04,753,NOVT [HdrWriter]     force serv |      5 |   8.4% |    1.236 |    1.376 |    1.738 |    16.93 |    1.266 |     3929 |      781 |     3929 
...
2023-05-22 20:00:59,720,NOVT [HdrWriter]     force serv |     60 | 100.0% |    1.109 |    1.286 |    1.496 |    5.879 |    1.143 |     4349 |      870 |    51281 
2023-05-22 20:00:59,722,NOVT [HdrWriter]     force resp |     60 | 100.0% |     8438 |     8651 |     8716 |     8724 |     8404 |     4352 |      870 |    51283 
2023-05-22 20:01:00,724,NOVT [TargetRunnerST] Result: RunResult(rateUnits=op/s, timeUnits=ms, actualRate=854.7333333333333, errors=0, count=51284, time=60000) 
2023-05-22 20:01:00,734,NOVT [BasicRunner] Reguested rate 1000 op/s (100%) , actual rate 855 op/s 
2023-05-22 20:01:00,735,NOVT [BasicRunner] ----------------------------------------------------- 
2023-05-22 20:01:00,736,NOVT [BasicRunner] Run once: io-tussle (step 1) finished 
2023-05-22 20:01:00,737,NOVT [BasicRunner] Results (step 1) 
2023-05-22 20:01:00,737,NOVT [BasicRunner] Count: 51284 
2023-05-22 20:01:00,738,NOVT [BasicRunner] Time: 60 s 
2023-05-22 20:01:00,739,NOVT [BasicRunner] Rate: 855 op/s 
2023-05-22 20:01:00,740,NOVT [BasicRunner] Errors: 0 
2023-05-22 20:01:00,743,NOVT [BasicRunner] force response_time time: 61 s 
2023-05-22 20:01:00,744,NOVT [BasicRunner] force response_time p0: 2.37 ms 
2023-05-22 20:01:00,745,NOVT [BasicRunner] force response_time p50: 4895 ms 
2023-05-22 20:01:00,746,NOVT [BasicRunner] force response_time p90: 7926 ms 
2023-05-22 20:01:00,746,NOVT [BasicRunner] force response_time p99: 8643 ms 
2023-05-22 20:01:00,747,NOVT [BasicRunner] force response_time p99.9: 8708 ms 
2023-05-22 20:01:00,748,NOVT [BasicRunner] force response_time p99.99: 8724 ms 
2023-05-22 20:01:00,749,NOVT [BasicRunner] force response_time p100: 8724 ms 
2023-05-22 20:01:00,752,NOVT [BasicRunner] force response_time mean: 4781 ms 
2023-05-22 20:01:00,753,NOVT [BasicRunner] force response_time rate: 841 op/s 
...
```

## SQL benchmark <a name="sql"/>
Project location: [sql-benchmark](sql-benchmark)
Build:
```
$ cd sql-benchmark/
$ mvn clean package -DskipTests
```
Usage
```
$ java -jar target/sql-benchmark-*.jar  [...benchmark-args]  [--runner {tussle-benchmark-runner}  [{...runner-args}]]
```
Run:
```
# Test default SQL configuration: H2 database started as part of benchmark
$ java -jar target/sql-benchmark-*.jar
```
Results:
```
benchmark.log - benchmark output file
histograms - directory containing collected result histograms which can be processed and visualized using corresponding tool from the Tussle Framework
```
Output:
```
2023-05-22 20:39:47,303,NOVT [BasicRunner] Benchmark config: !!org.tussleframework.benchmark.SQLBenchmarkConfig {async: false, driver: org.h2.Driver,
...
warmupTime: '0' 
2023-05-22 20:39:47,364,NOVT [BasicRunner] =================================================================== 
2023-05-22 20:39:47,365,NOVT [BasicRunner] Run once: sql (step 1) started 
2023-05-22 20:39:47,366,NOVT [BasicRunner] Benchmark reset... 
2023-05-22 20:39:47,372,NOVT [BasicRunner] Benchmark run at target rate 1000 op/s (100%), warmup 0 s, run time 60 s... 
2023-05-22 20:39:47,390,NOVT [TargetRunnerST] Starting: target rate 1000 op/s, time 60000 ms... 
2023-05-22 20:39:52,395,NOVT [HdrWriter] -------------------------------------------------------------------------------------------------------------------------- 
2023-05-22 20:39:52,398,NOVT [HdrWriter]           name |   time |  progr |    p50ms |    p90ms |    p99ms |   p100ms |     mean |    count |     rate |    total 
2023-05-22 20:39:52,399,NOVT [HdrWriter] -------------------------------------------------------------------------------------------------------------------------- 
2023-05-22 20:39:52,413,NOVT [HdrWriter]     write resp |      5 |   8.4% |    0.176 |    0.408 |    1.365 |    10.13 |   0.2511 |     5001 |      999 |     5001 
2023-05-22 20:39:52,417,NOVT [HdrWriter]     write serv |      5 |   8.4% |    0.133 |    0.346 |     0.78 |    10.12 |   0.1798 |     5024 |     1000 |     5024 
...
2023-05-22 20:40:47,390,NOVT [HdrWriter]     write serv |     60 | 100.0% |    0.082 |    0.173 |    0.262 |    26.13 |   0.1017 |     4995 |     1000 |    59999 
2023-05-22 20:40:47,399,NOVT [HdrWriter]     write resp |     60 | 100.0% |    0.124 |    0.238 |    0.399 |    26.19 |   0.2109 |     5000 |     1000 |    60000 
2023-05-22 20:40:48,392,NOVT [TargetRunnerST] Result: RunResult(rateUnits=op/s, timeUnits=ms, actualRate=1000.0, errors=0, count=60000, time=60000) 
2023-05-22 20:40:48,396,NOVT [BasicRunner] Reguested rate 1000 op/s (100%) , actual rate 1000 op/s 
2023-05-22 20:40:48,396,NOVT [BasicRunner] ----------------------------------------------------- 
2023-05-22 20:40:48,397,NOVT [BasicRunner] Run once: sql (step 1) finished 
2023-05-22 20:40:48,397,NOVT [BasicRunner] Results (step 1) 
2023-05-22 20:40:48,398,NOVT [BasicRunner] Count: 60000 
2023-05-22 20:40:48,398,NOVT [BasicRunner] Time: 60 s 
2023-05-22 20:40:48,398,NOVT [BasicRunner] Rate: 1000 op/s 
2023-05-22 20:40:48,399,NOVT [BasicRunner] Errors: 0 
2023-05-22 20:40:48,401,NOVT [BasicRunner] write response_time time: 60 s 
2023-05-22 20:40:48,402,NOVT [BasicRunner] write response_time p0: 0.022 ms 
2023-05-22 20:40:48,402,NOVT [BasicRunner] write response_time p50: 0.145 ms 
2023-05-22 20:40:48,403,NOVT [BasicRunner] write response_time p90: 0.255 ms 
2023-05-22 20:40:48,403,NOVT [BasicRunner] write response_time p99: 0.53 ms 
2023-05-22 20:40:48,404,NOVT [BasicRunner] write response_time p99.9: 8.359 ms 
2023-05-22 20:40:48,404,NOVT [BasicRunner] write response_time p99.99: 20.29 ms 
2023-05-22 20:40:48,405,NOVT [BasicRunner] write response_time p100: 26.19 ms 
2023-05-22 20:40:48,406,NOVT [BasicRunner] write response_time mean: 0.1809 ms 
2023-05-22 20:40:48,406,NOVT [BasicRunner] write response_time rate: 1000 op/s 
...
```

## ISV viewer<a name="isv-viewer"/>

Project location: [isv-viewer](isv-viewer)

See [README](isv-viewer/README.md) for details

