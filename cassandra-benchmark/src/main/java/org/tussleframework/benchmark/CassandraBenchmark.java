/*
 * Copyright (c) 2021-2023, Azul Systems
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

package org.tussleframework.benchmark;

import java.util.concurrent.atomic.AtomicLong;

import org.tussleframework.RunnableWithError;
import org.tussleframework.TussleException;
import org.tussleframework.WlBenchmark;
import org.tussleframework.WlConfig;

import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.Session;

/**
 * 
 * Run:
 *   java -jar target/tussle-demo-*.jar CassandraBenchmark {...benchmark-args} --runner BasicRunner {...runner-args}
 * 
 *
 */
public class CassandraBenchmark extends WlBenchmark {

    Process proc;
    Cluster cluster;
    Session session;
    CassandraBenchmarkConfig cassandraBenchmarkConfig;
    AtomicLong counter = new AtomicLong();

    public CassandraBenchmark() {
    }

    public CassandraBenchmark(String[] args) throws TussleException {
        init(args);
    }

    @Override
    public Class<? extends WlConfig> getConfigClass() {
        return CassandraBenchmarkConfig.class;
    }

    @Override
    public void init(String[] args) throws TussleException {
        super.init(args);
        // start apache-cassandra-4.0.7/bin/cassandra -f
        cassandraBenchmarkConfig = (CassandraBenchmarkConfig) super.config;
        cluster = Cluster.builder().addContactPoint(cassandraBenchmarkConfig.host).build();
        session = cluster.connect();
        session.execute(String.format("CREATE KEYSPACE IF NOT EXISTS %s WITH replication = {'class': 'SimpleStrategy', 'replication_factor' : 3}", cassandraBenchmarkConfig.keyspace));
        session.execute(String.format("USE %s", cassandraBenchmarkConfig.keyspace));
        reset();
    }

    @Override
    public void reset() throws TussleException {
        try {
            session.execute(String.format("DROP TABLE IF EXISTS %s", cassandraBenchmarkConfig.table));
            session.execute(String.format("CREATE TABLE %s (key text PRIMARY KEY, value1 text, value2 text, value3 text, value4 text, value5 text)", cassandraBenchmarkConfig.table));
        } catch (Exception e) {
            throw new TussleException(e);
        }
    }

    @Override
    public void cleanup() {
        try {
        	if (session != null) {
	            session.execute(String.format("DROP KEYSPACE IF EXISTS %s", cassandraBenchmarkConfig.keyspace));
	            session.close();
	            session = null;
        	}
        } finally {
        	if (cluster != null) {
        		cluster.close();
        		cluster = null;
        	}
        }
    }

    protected boolean write() {
        long num = counter.incrementAndGet();
        session.execute(String.format("INSERT INTO %s (key, value1, value2, value3, value4, value5) VALUES ('%s', '%s', '%s', '%s', '%s', '%s')", cassandraBenchmarkConfig.table, "key_" + num, "value1_" + num, "value2_" + num, "value3_" + num, "value4_" + num, "value5_" + num));
        return true;
    }

    @Override
    public String getName() {
        return "cassandra-demo";
    }

    @Override
    public RunnableWithError getWorkload() {
        return this::write;
    }

    @Override
    public String getOperationName() {
        return "write";
    }
}
