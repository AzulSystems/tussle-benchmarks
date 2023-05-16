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

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.concurrent.atomic.AtomicLong;

import org.h2.tools.Server;
import org.tussleframework.RunnableWithError;
import org.tussleframework.TussleException;
import org.tussleframework.WlBenchmark;
import org.tussleframework.WlConfig;

public class SQLBenchmark extends WlBenchmark {

    private SQLBenchmarkConfig sqlConfig;
    private AtomicLong counter = new AtomicLong();
    private Connection connection;
    private Statement session;
    private Server server;

    public SQLBenchmark() {
    }

    public SQLBenchmark(String[] args) throws TussleException {
        init(args);
    }

    @Override
    public Class<? extends WlConfig> getConfigClass() {
        return SQLBenchmarkConfig.class;
    }

    @Override
    public void init(String[] args) throws TussleException {
        super.init(args);
        sqlConfig = (SQLBenchmarkConfig) getConfig();
        try {
            server = Server.createTcpServer("-tcpAllowOthers").start();
            Class.forName(sqlConfig.driver);
            connection = DriverManager.getConnection(sqlConfig.url, sqlConfig.usr, sqlConfig.pwd);
            session = connection.createStatement();
        } catch (Exception e) {
            throw new TussleException(e);
        }
        reset();
    }

    @Override
    public void reset() throws TussleException {
        try {
            session.execute(String.format("DROP TABLE IF EXISTS %s", sqlConfig.tab));
            session.execute(String.format("CREATE TABLE `%s` (`key` TEXT PRIMARY KEY, `value1` TEXT, `value2` TEXT, `value3` TEXT, `value4` TEXT, `value5` TEXT)", sqlConfig.tab));
        } catch (Exception e) {
            throw new TussleException(e);
        }
    }

    @Override
    public void cleanup() {
        try {
            if (session != null) {
                session.close();
            }
        } catch (SQLException e) {
            // ignore
        } finally {
            session = null;
        }
        try {
            if (connection != null) {
                connection.close();
            }
        } catch (SQLException e) {
            /// ignore
        } finally {
            connection = null;
        }
        if (server != null) {
            server.stop();
            server = null;
        }
    }

    protected boolean write() {
        long num = counter.incrementAndGet();
        try {
            session.executeUpdate(String.format("INSERT INTO `%s` (`key`, `value1`, `value2`, `value3`, `value4`, `value5`) VALUES ('%s', '%s', '%s', '%s', '%s', '%s')", sqlConfig.tab, "key_" + num, "value1_" + num, "value2_" + num, "value3_" + num, "value4_" + num, "value5_" + num));
        } catch (SQLException e) {
            return false;
        }
        return true;
    }

    @Override
    public String getName() {
        return "sql";
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
