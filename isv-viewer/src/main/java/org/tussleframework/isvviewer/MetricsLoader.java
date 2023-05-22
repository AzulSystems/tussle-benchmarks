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

import static org.tussleframework.isvviewer.Utils.doubleValue;
import static org.tussleframework.isvviewer.Utils.findIndex;
import static org.tussleframework.isvviewer.Utils.isDoubleValue;
import static org.tussleframework.isvviewer.Utils.join;
import static org.tussleframework.isvviewer.Utils.maxd;
import static org.tussleframework.isvviewer.Utils.split;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.text.ParseException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.http.HttpHeaders;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.tussleframework.isvviewer.metrics.DocData;
import org.tussleframework.isvviewer.metrics.MetricDoc;
import org.tussleframework.isvviewer.metrics.Metrics;
import org.tussleframework.isvviewer.metrics.MetricsList;
import org.tussleframework.isvviewer.metrics.RunProps;
import org.tussleframework.isvviewer.metrics.RunPropsDoc;
import org.tussleframework.metrics.Marker;
import org.tussleframework.metrics.Metric;
import org.tussleframework.metrics.MetricValue;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;

@Service
public class MetricsLoader {

    public static final String UNKNOWN = "unknown";
    public static final String START = "<a href=\"";
    public static final String EXT_METRIC1 = ".metric";
    public static final String EXT_METRIC2 = ".aggregates";
    public static final String METRIC_ON = "metric on";
    public static final String METRIC_VALUE = "value";
    public static final String METRIC_UNITS = "units";
    public static final String RUN_PROPERTIES1 = "run-properties.json";
    public static final String RUN_PROPERTIES2 = "run.properties.json";
    public static final String METRICS_JSON = "metrics.json";
    public static final String METRICS_DIR = "metrics";
    public static final String BENCHMARK_DIR = "benchmark_";
    public static final String HISTOGRAMS_DIR = "histograms";
    public static final String RUN_PROPERTIES_BENCHMARK_LOG = "run-benchmark.log";
    public static final String PERFWEB_HEADER = "perfweb.header";

    private final Log log = LogFactory.getLog(getClass());

    @Lazy
    @Autowired
    private RestTemplate restTemplate;

    private static boolean isBenchmarkDr(String dir) {
        if (!dir.startsWith(BENCHMARK_DIR)) {
            return false;
        }
        dir = dir.substring(BENCHMARK_DIR.length());
        while (dir.endsWith("/")) {
            dir = dir.substring(0, dir.length() - 1);
        }
        try {
            Integer.valueOf(dir);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static Metric metric(String name, String scale, String xscale, Collection<Double> values) {
        Metric metric = Metric.builder()
                .name(name)
                .units(scale)
                .xunits(xscale)
                .build();
        values.stream().mapToDouble(Double::doubleValue).toArray();
        metric.add(new MetricValue("values", values.stream().mapToDouble(Double::doubleValue).toArray()));
        return metric;
    }

    public static String hostNameFromUrl(String baseUrl, String metricUrl) {
        String metricHost = null;
        String fileDir = metricUrl.substring(baseUrl.length());
        if (fileDir.indexOf("node_") >= 0) {
            metricHost = fileDir.substring(fileDir.indexOf("node_") + 5);
            int pos = metricHost.indexOf('/');
            if (pos >= 0) {
                metricHost = metricHost.substring(0, pos);
            }
        }
        return metricHost;
    }

    private HttpResponse doGet(String url) throws IOException {
        String userAgent = "ISVViewerAgent/1.Z";
        try (CloseableHttpClient httpClient = HttpClients.createDefault()) {
            HttpGet httpGet = new HttpGet(url);
            httpGet.setHeader(HttpHeaders.USER_AGENT, userAgent);
            return httpClient.execute(httpGet);
        }
    }

    protected InputStream getStream(String url) throws IOException {
        File file = new File(url.replace("http://release", ""));
        if (file.exists()) {
            if (file.isDirectory()) {
                log.info("getStream dir: " + file);
                StringBuilder sb = new StringBuilder();
                for (File f : file.listFiles()) {
                    log.info("getStream f: " + f);
                    if (f.isDirectory()) {
                        sb.append("dir:").append(f.getName()).append("/\n");
                    } else {
                        sb.append("file:").append(f.getName()).append("\n");
                    }
                }
                return new ByteArrayInputStream(sb.toString().getBytes());
            }
            log.info("getStream file: " + file);
            return new FileInputStream(file);
        }
        log.info("getStream url: " + url);
        HttpResponse response = doGet(url);
        log.info("getStream status code: " + response.getStatusLine().getStatusCode());
        if (response.getStatusLine().getStatusCode() == 200) {
            return response.getEntity().getContent();
        } else {
            return null;
        }
    }

    protected void listDir(InputStream is, ArrayList<String> files, ArrayList<String> dirs) {
        try (java.util.Scanner s = new java.util.Scanner(is)) {
            while (s.hasNext()) {
                String line = s.nextLine();
                if (line.indexOf("Parent Directory") >= 0) {
                } else if (line.startsWith("<tr><td valign=\"top\"><img src=")) {
                    int start = line.indexOf(START);
                    if (start > 0) {
                        int end = line.indexOf("\">", start);
                        if (end > 0) {
                            boolean isDir = line.indexOf("alt=\"[DIR]\"") >= 0;
                            String item = line.substring(start + START.length(), end);
                            (isDir ? dirs : files).add(item);
                        }
                    }
                } else if (line.startsWith("file:")) {
                    files.add(line.substring("file:".length()));
                } else if (line.startsWith("dir:")) {
                    dirs.add(line.substring("dir:".length()));
                }
            }
        }
    }

    protected void searchResults(InputStream is, String baseUrl, MetricsList mlist) {
        log.info("searchResults: " + baseUrl + "...");
        ArrayList<String> files = new ArrayList<>();
        ArrayList<String> dirs = new ArrayList<>();
        listDir(is, files, dirs);
        RunProps runProperties = new RunProps();
        if (getConfig(baseUrl, files, dirs, runProperties)) {
            String resDir = baseUrl.replace("http://release", "");
            log.info("searchResults found resDir:" + resDir);
            runProperties.results_dir = resDir;
            mlist.docs.add(runProperties);
            return;
        }
        dirs.forEach(dir -> {
            String subdirUrl = baseUrl;
            if (dir.startsWith("/") || subdirUrl.endsWith("/")) {
                subdirUrl += dir;
            } else {
                subdirUrl += "/" + dir;
            }
            try (InputStream response = getStream(subdirUrl)) {
                if (response != null) {
                    searchResults(response, subdirUrl, mlist);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    protected boolean getConfig(String baseUrl, ArrayList<String> files, ArrayList<String> dirs, RunProps runProperties) {
        AtomicInteger cnt = new AtomicInteger(0);
        if (files.stream().anyMatch(file -> file.equals(PERFWEB_HEADER))) {
            return false;
        }
        files.forEach(file -> {
            if (file.equals(RUN_PROPERTIES_BENCHMARK_LOG)) {
                log.info("processing: " + file + "...");
                cnt.incrementAndGet();
                if (runProperties != null && runProperties.isEmpty()) {
                    getRunProperties(file, baseUrl, runProperties);
                }
            }
        });
        dirs.forEach(dir -> {
            if (isBenchmarkDr(dir)) {
                log.info("processing dir: " + dir + "...");
                cnt.incrementAndGet();
            }
        });
        if (cnt.get() == 0) {
            files.forEach(file -> {
                if (file.equals(RUN_PROPERTIES1) || file.equals(RUN_PROPERTIES2) || file.equals(METRICS_JSON)) {
                    log.info("processing: " + file + "...");
                    cnt.incrementAndGet();
                    if (runProperties != null && runProperties.isEmpty()) {
                        getRunProperties(file, baseUrl, runProperties);
                    }
                }
            });
        } else if (runProperties != null) {
            log.info("runProperties.benchmark: " + runProperties.benchmark);
        }
        if (cnt.get() == 0 && runProperties != null && runProperties.isEmpty()) {
            runProperties.config = baseUrl;
        }
        return cnt.get() > 0;
    }

    protected void processDir(InputStream is, String baseUrl, RunProps runProperties, ArrayList<String> metricFiles, boolean processDirsRec) {
        String parentDir = baseUrl;
        while (parentDir.endsWith("/")) {
            parentDir = parentDir.substring(0, parentDir.length() - 1);
        }
        int pos = parentDir.lastIndexOf("/");
        if (pos >= 0) {
            parentDir = parentDir.substring(pos + 1);
        }
        ArrayList<String> files = new ArrayList<>();
        ArrayList<String> dirs = new ArrayList<>();
        listDir(is, files, dirs);
        getConfig(baseUrl, files, dirs, runProperties);
        files.forEach(fileName -> {
            if (fileName.endsWith(EXT_METRIC1) || fileName.endsWith(EXT_METRIC2) || fileName.equals(METRICS_JSON)) {
                log.info("found metrics: " + fileName);
                String meticUrl = baseUrl;
                if (!meticUrl.endsWith("/")) {
                    meticUrl += "/";
                }
                meticUrl += fileName;
                metricFiles.add(meticUrl);
            } else {
                log.info("ignored non-metrics: " + fileName);
            }
        });
        dirs.forEach(dir -> {
            if (dir.startsWith(METRICS_DIR) || isBenchmarkDr(dir) || dir.startsWith(HISTOGRAMS_DIR) || processDirsRec) {
                log.info("processing dir: " + dir + "...");
                String subdirUrl = baseUrl + "/" + dir;
                try (InputStream response = getStream(subdirUrl)) {
                    if (response != null) {
                        processDir(response, subdirUrl, runProperties, metricFiles, processDirsRec);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        });
    }

    protected MetricDoc processResults(String id, InputStream is, String baseUrl, boolean processDirsRec) {
        log.info("processDir: " + baseUrl + ", recursive=" + processDirsRec + "...");
        ArrayList<String> metricUrls = new ArrayList<>();
        RunProps runProperties = new RunProps();
        runProperties.results_dir = baseUrl.replace("http://", "");
        if (runProperties.results_dir.startsWith("release/")) {
            runProperties.results_dir = runProperties.results_dir.substring("release".length());
        }
        processDir(is, baseUrl, runProperties, metricUrls, processDirsRec);
        ArrayList<Metric> metrics = new ArrayList<>();
        for (String metricUrl : metricUrls) {
            RunProps props = getMetric(baseUrl, metricUrl, metrics, runProperties);
            if (props != null && !props.isEmpty()) {
                log.info("Found run properties in metrics file: " + metricUrl);
                runProperties = props;
            }
        }
        log.info("processDir result: " + baseUrl + " config: " + runProperties.config);
        return new MetricDoc(id, new DocData(metrics, runProperties, null), null, null);
    }

    static String[] splitTUS(String line) {
        return line.replace("interval endtime", "interval_endtime").replaceAll("\\(.+?\\)", "").replace("th, ", "th/").replaceFirst("\\S+", "").replaceAll("\\s+", "")
                .split("\\|");
    }

    @SuppressWarnings("unchecked")
    protected void processKafkaTUS(InputStream is, ArrayList<Metric> allMetrics) {
        ArrayList<ArrayList<Double>> data = new ArrayList<>();
        final String s1 = "Processing histogram for ";
        final String s2 = " | ";
        String[] labels = null;
        try (java.util.Scanner s = new java.util.Scanner(is)) {
            String label = "";
            String[] values;
            ArrayList<Double>[] ms = null;
            while (s.hasNext()) {
                String line = s.nextLine();
                if (line.indexOf(s1) >= 0) {
                    label = line.substring(line.indexOf(s1) + s1.length());
                    log.info(" -- : " + label);
                    if (ms != null) {
                        // flush data
                        while (data.size() < ms.length) {
                            data.add(new ArrayList<>());
                        }
                        for (int i = 0; i < ms.length; i++) {
                            double max = maxd(ms[i]);
                            data.get(i).add(max);
                        }
                    }
                } else if (line.indexOf(s2) >= 1) {
                    if (line.startsWith("interval_endtime")) {
                        labels = splitTUS(line);
                        ms = new ArrayList[labels.length - 1];
                        for (int i = 1; i < labels.length; i++) {
                            ms[i - 1] = new ArrayList<>();
                        }
                    } else if (ms != null) {
                        values = splitTUS(line);
                        for (int i = 1; i < values.length; i++) {
                            ms[i - 1].add(doubleValue(values[i]));
                        }
                    }
                }
            }
            for (int i = 0; i < data.size(); i++) {
                allMetrics.add(metric("latency " + labels[i + 1], "ms", "endtime", data.get(i)));
            }
        }
    }
    
    protected void processHDInsight(InputStream is, ArrayList<Metric> allMetrics) {
        ArrayList<Metric> metrics = new ArrayList<>();
        try (java.util.Scanner s = new java.util.Scanner(is)) {
            String header = s.nextLine();
            log.info("times_raw.csv header: " + header);
            String curQuery = "";
            ArrayList<Double> values = new ArrayList<>();
            while (s.hasNext()) {
                String line = s.nextLine();
                if (line.startsWith("sparksettings")) {
                    curQuery = "";
                    continue;
                }
                String[] fields = split(line, true);
                String query = fields[0].replaceAll(".sql", "");
                if (curQuery.isEmpty()) {
                    curQuery = query;
                }
                if (curQuery.equals(query)) {
                    values.add(doubleValue(fields[4]));
                } else if (!values.isEmpty()) {
                    metrics.add(metric(curQuery, "s", "iterations", values));
                    values.clear();
                    curQuery = query;
                } else {
                    log.info("times_raw.csv fields: " + join(fields, " / ") + " = " + query + " : " + values.size());
                }
            }
            if (!values.isEmpty()) {
                metrics.add(metric(curQuery, "s", "iterations", values));
                values.clear();
            }
            metrics.forEach(allMetrics::add);
        }
    }

    protected void processMetricData(InputStream is, String fileName, String metricHost, ArrayList<Metric> allMetrics, RunProps runProperties) throws ParseException {
        log.info(String.format("processMetricData [host:%s] %s...", metricHost, fileName));
        ArrayList<Metric> metrics = new ArrayList<>();
        ArrayList<ArrayList<Double>> data = new ArrayList<>();
        String theName = fileName;
        if (fileName.endsWith(EXT_METRIC1)) {
            theName = fileName.substring(0, fileName.indexOf(EXT_METRIC1));
        } else if (fileName.endsWith(EXT_METRIC2)) {
            theName = fileName.substring(0, fileName.indexOf(EXT_METRIC2));
        }
        ArrayList<String> stringXValues = new ArrayList<>();
        String[] colNames = {};
        ArrayList<String> addedNames = new ArrayList<>();
        ArrayList<Marker> markers = new ArrayList<>();
        try (java.util.Scanner s = new java.util.Scanner(is)) {
            int lineNo = 0;
            while (s.hasNext()) {
                String line = s.nextLine();
                if (line.trim().startsWith("#")) {
                    continue;
                }
                if (lineNo == 0) {
                    // first line = column names
                    colNames = split(line, true);
                    if (colNames.length == 0) {
                        log.info("skip metric with empty columns");
                        return;
                    }
                    lineNo++;
                    continue;
                }
                // parse values
                String[] values = split(line, true);
                // process 'Metric on'
                if (colNames[0].equalsIgnoreCase(METRIC_ON)) {
                    Metric metric = Metric.builder().name(theName).operation(values[0]).build();
                    int valueIdx = findIndex(colNames, METRIC_VALUE);
                    if (valueIdx >= 0 && valueIdx < values.length) {
                        metric.setValue(doubleValue(values[valueIdx]));
                    } else {
                        metric.setValue(-1.0);
                    }
                    int unitsIdx = findIndex(colNames, METRIC_UNITS);
                    if (unitsIdx >= 0 && unitsIdx < values.length) {
                        metric.setUnits(values[unitsIdx]);
                    }
                    allMetrics.add(metric);
                    continue;
                }
                // process regular table vales
                while (data.size() < values.length) {
                    data.add(new ArrayList<>());
                }
                while (metrics.size() < values.length - 1) {
                    int idx = metrics.size();
                    String name = theName;
                    String scale = "";
                    String xscale = null;
                    String n = idx < colNames.length - 1 ? colNames[idx + 1] : "";
                    if (n.indexOf('(') >= 0) {
                        int pos = n.indexOf('(');
                        int pos2 = n.indexOf(')', pos + 1);
                        scale = n.substring(pos + 1, pos2);
                        n = n.substring(0, pos);
                    } else {
                        scale = n;
                    }
                    if (n.indexOf(name) < 0 && name.indexOf(n) < 0) {
                        name += " " + n;
                    }
                    xscale = colNames[0];
                    int nn = 0;
                    while (true) {
                        nn++;
                        boolean uniq = true;
                        String nameTry = name;
                        if (nn > 1) {
                            nameTry = name + " " + nn;
                        }
                        for (int k = 0; k < addedNames.size(); k++) {
                            if (addedNames.get(k).equals(nameTry)) {
                                uniq = false;
                            }
                        }
                        if (uniq) {
                            name = nameTry;
                            break;
                        }
                    }
                    addedNames.add(name);
                    Metric metric = Metric.builder().name(name).units(scale).xunits(xscale).build();
                    if (!markers.isEmpty()) {
                        metric.setMarkers(markers);
                    }
                    if (!name.startsWith("_tmp_")) {
                        log.info("add metric " + name + " (" + xscale + " - " + scale + ")");
                        metrics.add(metric);
                    } else {
                        log.info("skip metric " + name + " (" + xscale + " - " + scale + ")");
                        metrics.add(null);
                    }
                }
                for (int i = 0; i < data.size(); i++) {
                    if (i == 0) {
                        String vs = values[i].trim();
                        if (!stringXValues.isEmpty() || !isDoubleValue(vs)) {
                            stringXValues.add(vs);
                        } else {
                            Double v = vs.length() > 0 ? doubleValue(vs) : lineNo;
                            data.get(i).add(v);
                        }
                    } else if (i < values.length) {
                        Double value = doubleValue(values[i]);
                        data.get(i).add(value);
                    } else {
                        data.get(i).add(-1d);
                    }
                }
            }
        }
        if (colNames[0].equalsIgnoreCase(METRIC_ON)) {
            return;
        }
        for (int i = 0; i < metrics.size(); i++) {
            Metric metric = metrics.get(i);
            if (metric == null) {
                continue;
            }
            ArrayList<Double> values = data.get(i + 1);
            if (stringXValues.isEmpty()) {
                metric.setXValues(data.get(0).stream().map(d -> d.toString()).toArray(String[]::new));
            } else {
                metric.setXValues(stringXValues.toArray(new String[0]));
            }
            metric.add(new MetricValue("values", values.stream().mapToDouble(Double::doubleValue).toArray()));
            metric.setHost(metricHost);
            allMetrics.add(metric);
        }
    }

    private ObjectReader objectReader = new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false).reader();

    protected <T> T getJson(String url, Class<T> type) {
        File file = new File(url.replace("http://release", ""));
        if (file.exists()) {
            log.info("getJson from file: " + file);
            try {
                return objectReader.readValue(file, type);
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }
        log.info("getJson from file: " + url);
        return restTemplate.getForObject(url, type);
    }

    protected RunProps getMetric(String baseUrl, String metricUrl, ArrayList<Metric> allMetrics, RunProps runProperties) {
        String fileName = metricUrl.substring(metricUrl.lastIndexOf('/') + 1);
        String metricHost = hostNameFromUrl(baseUrl, metricUrl);
        if (fileName.equals(METRICS_JSON)) {
            log.info("processing metrics.json/scores.json: " + metricUrl + "...");
            Metrics metrics = getJson(metricUrl, Metrics.class);
            log.info("getMetric - metrics size: " + (metrics.metrics != null ? metrics.metrics.size() : null));
            if (metrics.doc != null && metrics.doc.metrics != null) {
                metrics.doc.metrics.forEach(allMetrics::add);
            }
            if (metrics.metrics != null) {
                metrics.metrics.forEach(allMetrics::add);
            }
            if (metrics.doc.runProperties != null) {
                log.info("getMetric - metrics.doc.runProperties: " + metrics.doc.runProperties);
                return metrics.doc.runProperties;
            }
            log.info("getMetric - metrics.runProperties: " + metrics.runProperties);
            return metrics.runProperties;
        }
        log.info("processing metricUrl: " + metricUrl + " [" + fileName + "] ...");
        try (InputStream response = getStream(metricUrl)) {
            if (response != null) {
                processMetricData(response, fileName, metricHost, allMetrics, runProperties);
            }
        } catch (ParseException e) {
            log.info("Metrics parsing exception: " + e);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    protected int getRunProperties(String runLog, String baseUrl, RunProps runProperties) {
        if (runProperties == null) {
            return 0;
        }
        log.info("getRunProperties: " + baseUrl + " -- " + runLog);
        if (runLog.equals(RUN_PROPERTIES1) || runLog.equals(RUN_PROPERTIES2)) {
            RunPropsDoc runPropsDoc = getJson(baseUrl + "/" + runLog, RunPropsDoc.class);
            runProperties.copySome(runPropsDoc.doc.run_properties);
            return 1;
        }
        if (runLog.equals(RUN_PROPERTIES_BENCHMARK_LOG)) {
            try (InputStream response = getStream(baseUrl + "/" + runLog)) {
                if (response != null) {
                    try (java.util.Scanner s = new java.util.Scanner(response)) {
                        while (s.hasNext()) {
                            String line = s.nextLine();
                            if (line.startsWith("BENCHMARK:")) {
                                runProperties.application = runProperties.benchmark = line.substring("BENCHMARK:".length()).trim();
                                log.info("runProperties.benchmark: " + runProperties.benchmark);
                            } else if (line.startsWith("BUILD_NO:")) {
                                runProperties.build = line.substring("BUILD_NO:".length()).trim();
                            } else if (line.startsWith("CONFIG:")) {
                                runProperties.config = line.substring("CONFIG:".length()).trim();
                            } else if (line.startsWith("HOST:")) {
                                runProperties.host = line.substring("HOST:".length()).trim();
                            } else if (line.startsWith("VM_TYPE:")) {
                                runProperties.vm_type = line.substring("VM_TYPE:".length()).trim();
                            } else if (line.startsWith("JAVA_HOME:")) {
                                runProperties.vm_home = line.substring("JAVA_HOME:".length()).trim();
                            } else if (line.startsWith("WORKLOAD:")) {
                                runProperties.workload = line.substring("WORKLOAD:".length()).trim();
                            } else if (line.startsWith("WORKLOAD_NAME:")) {
                                runProperties.workload_name = line.substring("WORKLOAD_NAME:".length()).trim();
                            } else if (line.startsWith("WORKLOAD_PARAMETERS:")) {
                                runProperties.workload_parameters = line.substring("WORKLOAD_PARAMETERS:".length()).trim();
                            }
                        }
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            return 1;
        }
        if (runLog.equals(METRICS_JSON)) {
            if (!runProperties.vm_type.isEmpty() && !runProperties.vm_type.equals(UNKNOWN))
                return 0;
            runProperties.config = "";
            return 1;
        }
        return 0;
    }

    protected MetricDoc collectMetrics(String id, String url, boolean processDirsRec) {
        log.info("collectMetrics: " + url + " ... ");
        try (InputStream stream = getStream(url)) {
            if (stream != null) {
                return processResults(id, stream, url, processDirsRec);
            } else {
                log.error("collectMetrics getStream failed: " + null);
                return null;
            }
        } catch (Exception e) {
            log.error("collectMetrics getStream failed: " + e.getMessage());
            return null;
        }
    }

    protected MetricsList searchMetrics(String url) {
        log.info("searchMetrics: " + url + " ... ");
        MetricsList mlist = new MetricsList();
        try (InputStream stream = getStream(url)) {
            if (stream != null) {
                searchResults(stream, url, mlist);
            }
        } catch (Exception e) {
            log.error("searchMetrics failed: " + e.getMessage());
        }
        return mlist;
    }
}
