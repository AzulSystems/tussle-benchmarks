# Tussle benchmarks & tools

This repository contains bunch of benchmark and tools projects.

## Kafka benchmark

Available as separate project:
https://github.com/AzulSystems/kafka-benchmark

## Cassandra benchmark

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

Output:
```
2023-05-22 14:56:02,426,NOVT [BasicRunner] Benchmark config: !!org.tussleframework.benchmark.CassandraBenchmarkConfig
...
```

## HTTP client benchmark

[httpclient-benchmark-cli](httpclient-benchmark-cli)

## Springboot benchmark

[springboot-benchmark-app](springboot-benchmark-app)

## IO benchmark

[io-benchmark](io-benchmark)

## SQL benchmark

[sql-benchmark](sql-benchmark)
