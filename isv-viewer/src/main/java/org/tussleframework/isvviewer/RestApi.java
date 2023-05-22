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

package org.tussleframework.isvviewer;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.Enumeration;
import java.util.Iterator;
import java.util.regex.Pattern;

import javax.servlet.http.HttpServletRequest;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Lazy;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.tussleframework.isvviewer.metrics.MetricDocs;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@RestController
public class RestApi {

    private final Log log = LogFactory.getLog(getClass());
    private static final ObjectMapper mapper = new ObjectMapper();
    private static final String ES_URL_TEMPLATE = "http://%s%s";
    private static final String JFR_URL_SEARCH_TEMPLATE = "http://%s/%s/_search?pretty";

    @Lazy
    @Autowired
    RestTemplate restTemplate;

    @Autowired
    MetricsLoader metricsLoader;

    @Value("${es_host}")
    String esHost;

    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        log.info("restTemplate...");
        RestTemplate template = builder.build();
        ArrayList<HttpMessageConverter<?>> messageConverters = new ArrayList<>();
        MappingJackson2HttpMessageConverter converter = new MappingJackson2HttpMessageConverter();
        converter.setSupportedMediaTypes(Arrays.asList(MediaType.ALL));
        messageConverters.add(converter);
        template.setMessageConverters(messageConverters);
        return template;
    }

    @GetMapping(value = "/test/{p}", produces = MediaType.TEXT_PLAIN_VALUE)
    public Object data(@PathVariable String p, HttpServletRequest request) {
        StringBuilder sb = new StringBuilder();
        sb.append("p: " + p).append("\n");
        Enumeration<String> headerNames = request.getHeaderNames();
        while (headerNames.hasMoreElements()) {
            String headerName = headerNames.nextElement();
            String headerValue = request.getHeader(headerName);
            sb.append(headerName).append(": ").append(headerValue).append("\n");
        }
        sb.append("\n-------------------------------------------------\n");
        Object res = restTemplate.getForObject(String.format("http://%s/%s", esHost, p), Object.class);
        sb.append(res);
        sb.append("\n-------------------------------------------------\n");
        return sb;
    }

    @GetMapping(value = "/benchmarks/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public Object benchmarks(HttpServletRequest request) {
        String url = String.format(ES_URL_TEMPLATE, esHost , request.getServletPath());
        log.info("benchmarks get: " + url);
        Object res = restTemplate.getForObject(url, Object.class);
        log.info("benchmarks got: " + url);
        return res;
    }

    @PostMapping(value = "/benchmarks/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public Object benchmarks(HttpServletRequest request, HttpEntity<Object> entity) throws JsonProcessingException {
        String url = String.format(ES_URL_TEMPLATE, esHost , request.getServletPath());
        log.info("benchmarks post: " + url + " - data: " + mapper.writeValueAsString(entity.getBody()));
        Object res = restTemplate.postForObject(url, entity, Object.class);
        log.info("benchmarks posted: " + url);
        return res;
    }

    @GetMapping(value = "/reports/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public Object reports(HttpServletRequest request) {
        String url = String.format(ES_URL_TEMPLATE, esHost , request.getServletPath());
        log.info("reports getting: " + url);
        Object res = restTemplate.getForObject(url, Object.class);
        log.info("reports got: " + url);
        return res;
    }

    @PostMapping(value = "/reports/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public Object reports(HttpServletRequest request, HttpEntity<Object> entity) {
        String url = String.format(ES_URL_TEMPLATE, esHost , request.getServletPath());
        log.info("reports posting: " + url);
        Object res = restTemplate.postForObject(url, entity, Object.class);
        log.info("reports posted: " + url);
        return res;
    }

    @GetMapping(value = "/release/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public Object metrics(HttpServletRequest request, @RequestParam(name = "rec", defaultValue = "false", required = false) String processDirsRec) {
        String pathesAll = request.getServletPath().substring("/release".length());
        String[] pathes = pathesAll.split(",");
        log.info("Getting metrics " + pathes.length + " pathes " + " processDirsRec=" + processDirsRec + " ...");
        MetricDocs docs = new MetricDocs();
        for (String path : pathes) {
            log.info("Getting metrics for: " + path + " ...");
            if (path.startsWith("/nsk-fs1")) {
                docs.docs.add(metricsLoader.collectMetrics(path, "http:/" + path, processDirsRec.equals("true")));
            } else {
                docs.docs.add(metricsLoader.collectMetrics(path, "http://release" + path, processDirsRec.equals("true")));
            }
        }
        return docs;
    }

    @GetMapping(value = "/echo", produces = MediaType.TEXT_PLAIN_VALUE)
    public Object echo(HttpServletRequest request) {
        StringBuilder sb = new StringBuilder();
        sb.append("ECHO RESPONSE:").append("\n");
        request.getParameterMap().keySet().forEach(key -> sb.append(key).append(" = ").append(Utils.join(request.getParameterMap().get(key), ", ")).append("\n"));
        return sb;
    }

    @GetMapping(value = "/search/**", produces = MediaType.APPLICATION_JSON_VALUE)
    public Object search(HttpServletRequest request) {
        String path = request.getServletPath().substring("/search".length());
        log.info("Searching metrics " + path + "...");
        log.info("Getting metrics for: " + path + " ...");
        if (path.startsWith("/nsk-fs1")) {
            return metricsLoader.searchMetrics("http:/" + path);
        } else {
            return metricsLoader.searchMetrics("http://release" + path);
        }
    }

    //
    // JFR controller
    //

    @Value("${jfr_host}")
    String jfrHost;

    @Value("${flamegraph_cmd}")
    String flamegraphCmd;

    public static boolean isRegexp(String exp) {
        return exp.indexOf(".*") >= 0 || exp.indexOf(".?") >= 0;
    }

    public static Pattern getPattern(String pat) {
        Pattern pattern = null;
        if (pat != null && pat.length() > 0) {
            if (!isRegexp(pat)) {
                pat = pat.replace("*", ".*").replace("?", ".?");
            }
            pattern = Pattern.compile(pat);
        }
        return pattern;
    }

    public String[] getFlameGraphCmd(String opts) {
        ArrayList<String> args = new ArrayList<>();
        args.add(flamegraphCmd);
        if (opts != null) {
            Arrays.stream(opts.split(",")).forEach(opt -> {
                if (opt.length() > 0) {
                    String[] optx = opt.split("_");
                    for (int i = 0; i < optx.length; i++) {
                        args.add(i == 0 ? "--" + optx[i] : optx[i]);
                    }
                }
            });
        }
        return args.toArray(new String[0]);
    }

    public String cutStack(String stack, Pattern cutStackPattern, boolean cutEnd) {
        if (cutStackPattern == null) {
            /// log.info(" -- " + stack + " =")
            return stack;
        }
        StringBuilder sb = new StringBuilder();
        String[] elems = stack.split(";");
        int i = 0;
        for (; i < elems.length - 1; i++) {
            if (cutEnd) {
                if (sb.length() > 0) sb.append(";");
                sb.append(elems[i]);
            }
            if (cutStackPattern.matcher(elems[i]).matches()) {
                break;
            }
        }
        if (!cutEnd) {
            for (; i < elems.length - 1; i++) {
                if (sb.length() > 0) sb.append(";");
                sb.append(elems[i]);
            }
        }
        /// log.info(" -- " + stack + " -> " + sb)
        return sb.toString();
    }

    public Object generateFlameGraph(Collection<JFRHit> hits, String cutPattern, boolean cutEnd, String opts) throws IOException {
        log.info("generateFlameGraph...");
        ProcessBuilder pb = new ProcessBuilder(getFlameGraphCmd(opts));
        Process proc = pb.start();
        Pattern cutStackPattern = getPattern(cutPattern);
        try (BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(proc.getOutputStream()))) {
            Iterator<JFRHit> it = hits.iterator();
            while (it.hasNext()) {
                JFRHit hit = it.next();
                writer.append(String.format("%s %d%n", cutStack(hit._source.stack, cutStackPattern, cutEnd), hit._source.count));
            }
        }
        String lf = String.format("%n");
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append(lf);
            }
        }
        return sb;
    }

    public Object getFlameGraph(JFRResult responseBody, String cutPattern, boolean cutEnd, String opts) throws IOException {
        log.info("flamegraph got response:");
        if (responseBody != null) {
            log.info("flamegraph took: " + responseBody.took + "ms, size: " + responseBody.getHits().getHits().size());
            return generateFlameGraph(responseBody.getHits().getHits(), cutPattern, cutEnd, opts);
        } else {
            log.info("flamegraph null");
        }
        return null;
    }

    @PostMapping(value = "/flamegraph/**", produces = "image/svg+xml")
    @ResponseBody
    public Object flamegraph(@RequestParam(name = "index", required = true, defaultValue = "jfr2") String index
            , @RequestParam(name = "stack", required = false) String cutPattern
            , @RequestParam(name = "opts", required = false) String opts
            , @RequestParam(name = "cutEnd", required = false) boolean cutEnd
            , HttpEntity<?> entity) throws IOException {
        log.info("flamegraph1: index=" + index + ", req=" + mapper.writeValueAsString(entity.getBody()));
        String url = String.format(JFR_URL_SEARCH_TEMPLATE, jfrHost, index);
        log.info("flamegraph1: url=" + url);
        JFRResult responseBody = restTemplate.postForObject(url, entity, JFRResult.class);
        return getFlameGraph(responseBody, cutPattern, cutEnd, opts);
    }

    @GetMapping(value = "/flamegraph/**", produces = "image/svg+xml")
    @ResponseBody
    public Object flamegraph(@RequestParam(name = "index", required = false, defaultValue = "jfr2") String index
            , @RequestParam(name = "cut", required = false) String cut
            , @RequestParam(name = "opts", required = false) String opts
            , @RequestParam(name = "workload", required = false) String workload
            , @RequestParam(name = "stack", required = false) String stack) throws IOException {
        log.info("flamegraph2: index=" + index + ", workload=" + workload + ", stack=" + stack);
        String regexpSrch = "{\"regexp\":{\"%s\":{\"value\":\"%s\",\"flags\":\"ALL\",\"case_insensitive\":true,\"rewrite\":\"constant_score\"}}}";
        String wildcardSrch = "{\"wildcard\":{\"%s\":{\"value\":\"%s\",\"case_insensitive\":true,\"rewrite\":\"constant_score\"}}}";
        String srch = "";
        if (workload != null && workload.length() > 0) {
            srch += String.format(isRegexp(workload) ? regexpSrch : wildcardSrch, "workload", workload);
        }
        if (stack != null && stack.length() > 0) {
            if (srch.length() > 0) {
                srch += ", ";
            }
            srch += String.format(isRegexp(stack) ? regexpSrch : wildcardSrch, "stack", stack);
        }
        String req = String.format("{\"size\":1000000,\"query\":{\"bool\":{\"must\":[ %s ]}}}", srch);
        log.info("flamegraph1: req=" + req);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));
        HttpEntity<?> entity = new HttpEntity<>(mapper.readTree(req), headers);
        String cutPattern = cut != null && (cut.equals("true") || cut.equals("start") || cut.equals("end")) ? stack : null;
        boolean cutEnd = cut != null && cut.equals("end");
        return flamegraph(index, cutPattern, opts, cutEnd, entity);
    }
}
