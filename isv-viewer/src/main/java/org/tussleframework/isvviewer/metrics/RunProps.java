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

package org.tussleframework.isvviewer.metrics;

import org.tussleframework.isvviewer.Utils;

import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class RunProps {
    public String id = "";
    public String start_time = "";
    public String finish_time = "";
    public String application = "";
    public String benchmark = "";
    public String workload = "";
    public String workload_name = "";
    public String workload_parameters = "";
    public String os = "";
    public String vm_type = "";
    public String vm_home = "";
    public String vm_args = "";
    public String vm_version = "";
    public String client_vm_home;
    public String client_vm_args;
    public String host = "";
    public String build = "";
    public String build_type = "";
    public String config = "";
    public String results_dir = "";

    public static String idFromTime(String startTime) {
        // 2021-11-09T19:59:51
        return startTime.replace(":", "").replace("-", "") + "Z";
    }

    public boolean isEmpty() {
        return Utils.isEmpty(config)
                && Utils.isEmpty(benchmark)
                && Utils.isEmpty(workload)
                && Utils.isEmpty(application)
                && Utils.isEmpty(build)
                && Utils.isEmpty(vm_type)
                ;
    }

    public void copySome(RunProps p) {
        id = idFromTime(p.start_time);
        vm_type = p.vm_type;
        vm_home = p.vm_home;
        build = p.build;
        config = p.config;
        host = p.host;
        application = p.application;
        benchmark = p.benchmark;
        workload = p.workload;
        workload_name = p.workload_name;
        workload_parameters = p.workload_parameters;
    }
}
