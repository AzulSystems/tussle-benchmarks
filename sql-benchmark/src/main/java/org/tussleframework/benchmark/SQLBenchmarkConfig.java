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

import java.util.Arrays;

import org.tussleframework.WlConfig;

import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;

@Data
@ToString(callSuper = false)
@EqualsAndHashCode(callSuper = false)
public class SQLBenchmarkConfig extends WlConfig {

    public String driver = "";
    public String type = "h2";
    public String tab = "demo_table";
    public String url = "";
    public String usr = "sa";
    public String pwd = "sa";
    
    @Override
    public void validate(boolean runMode) {
        super.validate(runMode);
        if (!Arrays.asList("h2", "postgresql").contains(type)) {
            throw new IllegalArgumentException(String.format("Unsupported database type: %s", type));
        }
        if (url == null || url.isEmpty()) {
            if (type.equals("h2")) {
                url = "jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1";
            } else if (type.equals("postgresql")) {
                url = "jdbc:postgresql://localhost/testdb";
            }
        }
        if (driver == null || driver.isEmpty()) {
            driver = String.format("org.%s.Driver", type);
        }
    }
}
