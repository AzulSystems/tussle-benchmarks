# Tussle benchmarks & tools

### This repository contains bunch of benchmark and tools projects.
1. [tussle-framework](#tussle-framework)
2. [Kafka benchmark](#kafka)
3. [Cassandra benchmark](#cassandra)
4. [HTTP client benchmark](#http)
5. [Springboot benchmark](#springboot)
6. [IO benchmark](#io)
7. [SQL benchmark](#sql)

## Tussle Framework <a name="tussle-framework"/>

Tussle Framework is a separate project which includes common benchmark runners, metrics, results processors, reporting, and etc.:
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
$ java -jar target/cassandra-benchmark-*.jar  # 
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
2023-05-22 15:06:40,067,NOVT [BasicRunner] Runner config: !!org.tussleframework.runners.BasicRunnerConfig
collectOps: []
histogramsDir: ./histograms
...
2023-05-22 15:06:40,073,NOVT [BasicRunner] =================================================================== 
2023-05-22 15:06:40,074,NOVT [BasicRunner] Run once: cassandra-demo (step 1) started 
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
2023-05-22 15:07:41,417,NOVT [BasicRunner] Run once: cassandra-demo (step 1) finished 
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

[httpclient-benchmark-cli](httpclient-benchmark-cli)

## Springboot benchmark <a name="springboot"/>

[springboot-benchmark-app](springboot-benchmark-app)

## IO benchmark <a name="io"/>

[io-benchmark](io-benchmark)

## SQL benchmark <a name="sql"/>

[sql-benchmark](sql-benchmark)

## ISV viewer<a name="isv-viewer"/>

[isv-viewer](isv-viewer)
