## ISV viewer server

Build:
```
$ mvn clean package -DskipTests
```

Run server as standalone springboot application:
```
$ java -jar target/isv-viewer-*.war
```

View results using following URL format:
http://localhost:8080/perf/#!?{options}


URL Options:

&r - list of the results IDs (the results fetched from database) or paths (the results downloaded directly from filer or pre-processed by server)
http://localhost:8080/perf/#!?r=id1,id2,id3,...
http://localhost:8080/perf/#!?r=path1,path2,path3,...

&summary - summary format
http://localhost:8080/perf/#!?summary&r=id1,id2,id3,...
http://localhost:8080/perf/#!?summary&r=path1,path2,path3,...

&rec - recursive processing of provided path to the results
http://localhost:8080/perf/#!?rec&r=path1

&show - parameter for showing specific list of metrics which names matches to the given
http://localhost:8080/perf/#!?r=id1,id2,id3&show=metric_name1,metric_name2...
supported predefined values:
   all - show all metrics (charts and aggregate values) by default
   allcharts - show all charts but do not show aggregate values by default
   allvalues - show all value-based aggregate values by default

Show graphs in specific folders:

http://localhost:8080/perf/#!?A&show=allcharts&r= path1>,<nfs path2>,<nfs path2>>

Note: If your resources are located in NSK nfs, you need to add "/nsk-fs1" prefix to view your data

&opts - general options for displaying data
http://localhost:8080/perf/#!?r=id1,id2,id3&show=all&opts=opt1,opts2...
supported options:
noMin - do not use minimal metric time az start point (zero), keep absolute time
dateTime - show full date + time lables
utc - show date/time


Examples:
default behavior:
opts=noMin
opts=noMin,dateTime
opts=noMin,dateTime,utc

&search - general options for searching results on filer in specified directory
http://localhost:8080/perf/#!?search=<nfs path>
Make URL for JIRA

Use "Charts" section to show or hide charts of interest:
- use buttons with labels with bold fonts  to show/hide chart groups
- use buttons with labels (normal font) to show/hide specific charts

Use "Values" section to show or hide numeric values of interest:
- use buttons with labels with bold fonts  to show/hide values groups
- use buttons with labels (normal font) to show/hide specific values

Click "Open Link" for column-based detailed view

or "Open Summary" for summary view

then copy URL from the new opened tab in the browser.

### Examples

View example resulys from [examples](examples):
http://localhost:8080/perf/#!?r=/local/path/to/tussle-benchmarks/isv-viewer/examples/res_omb_200k
http://localhost:8080/perf/#!?r=/local/path/to/tussle-benchmarks/isv-viewer/examples/res_omb_200k,/local/path/to/tussle-benchmarks/isv-viewer/examples/res_omb_1000k
