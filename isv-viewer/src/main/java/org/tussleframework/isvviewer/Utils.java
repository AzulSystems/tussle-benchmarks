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

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Date;
import java.util.Locale;
import java.util.Map;
import java.util.Scanner;

public class Utils {

    private static final SimpleDateFormat basic_date_format_z;
    private static final SimpleDateFormat basic_date_format_s;
    private static final SimpleDateFormat basic_date_format_ms;
    private static final SimpleDateFormat basic_date_format_ns;

    private static final DecimalFormat[] dfs = { new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)),
            new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)), new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)),
            new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)), new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)),
            new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)), new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)),
            new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)), new DecimalFormat("0", DecimalFormatSymbols.getInstance(Locale.ENGLISH)), };

    static {
        basic_date_format_z = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss:SSS Z");
        basic_date_format_s = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
        basic_date_format_ms = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss:SSS");
        basic_date_format_ns = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss.SSSSSSSSS");
        for (int i = 0; i < dfs.length - 1; i++) {
            dfs[i].setMaximumFractionDigits(i);
        }
        dfs[dfs.length - 1].setMaximumFractionDigits(20);
    }

    private Utils() {
    }

    public static int compare(double a, double b) {
        return a > b ? 1 : a < b ? -1 : 0;
    }

    public static void trimBuffer(StringBuilder buffer) {
        trimBuffer(buffer, ',');
    }

    public static void trimBuffer(StringBuilder buffer, char c) {
        if (buffer.length() > 0 && buffer.charAt(buffer.length() - 1) == c) {
            buffer.delete(buffer.length() - 1, buffer.length());
        }
    }

    public static String format(Float n, boolean round) {
        if (n == null) {
            return "-1";
        }
        return round ? roundFormat(n) : dfs[dfs.length - 1].format(n);
    }

    public static String format(double n, boolean round) {
        return round ? roundFormat(n) : dfs[dfs.length - 1].format(n);
    }

    public static String roundFormat(double n) {
        int digits;
        if (n == 0)
            return "0";
        if (n >= 200 || n <= -200)
            digits = 0;
        else if (n >= 100 || n <= -100)
            digits = 1;
        else if (n >= 10 || n <= -10)
            digits = 2;
        else if (n >= 1 || n <= -1)
            digits = 3;
        else if (n >= .1 || n <= -.1)
            digits = 4;
        else if (n >= .01 || n <= -.01)
            digits = 5;
        else if (n >= .001 || n <= -.001)
            digits = 6;
        else if (n >= .0001 || n <= -.0001)
            digits = 7;
        else
            digits = 8;
        return dfs[digits].format(n);
    }

    public static String extractParameterValue(String line, String parName) {
        int pos = line.indexOf(parName + "=");
        if (pos < 0)
            return null;
        line = line.substring(pos + parName.length() + 1);
        if ((pos = line.indexOf(",")) >= 0 || (pos = line.indexOf(" ")) >= 0 || (pos = line.indexOf(";")) >= 0 || (pos = line.indexOf(",")) >= 0) {
            line = line.substring(0, pos);
        }
        return line;
    }

    static Date parseDateTime(String text) throws ParseException {
        return basic_date_format_ms.parse(text);
    }

    static Date parseDateTimeZ(String text) throws ParseException {
        return basic_date_format_z.parse(text);
    }

    public static String convertStreamToString(java.io.InputStream is) {
        try (java.util.Scanner s = new java.util.Scanner(is)) {
            s.useDelimiter("\\A");
            return s.hasNext() ? s.next() : "";
        }
    }

    public static String join(Collection<?> arr) {
        return join(arr, ",");
    }

    public static String join(Collection<?> arr, String sep) {
        StringBuilder sb = new StringBuilder();
        for (Object obj : arr) {
            if (sep != null && sb.length() > 0) {
                sb.append(sep);
            }
            sb.append(obj);
        }
        return sb.toString();
    }

    public static String join(Object[] arr) {
        return join(arr, ",");
    }

    public static String join(Object[] arr, String sep) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < arr.length; i++) {
            if (sep != null && sb.length() > 0) {
                sb.append(sep);
            }
            sb.append(arr[i]);
        }
        return sb.toString();
    }

    public static int getIntValue(Map<String, String[]> map, String key, int def) {
        if (map.containsKey(key) && map.get(key).length > 0) {
            try {
                def = Integer.valueOf(map.get(key)[0]);
            } catch (Exception e) {
                // ignore
            }
        }
        return def;
    }

    public static String getStringValue(Map<String, String[]> map, String key, String def) {
        if (map.containsKey(key) && map.get(key).length > 0) {
            def = map.get(key)[0];
        }
        return def;
    }

    public static Float floatValue(String s) {
        s = s.trim();
        if (s.equals("NaN") || s.isEmpty())
            return -1f;
        try {
            return (float) basic_date_format_s.parse(s).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return (float) basic_date_format_ms.parse(s).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return (float) basic_date_format_ns.parse(s.replace("T", " ").replace("S", "")).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return Float.valueOf(s);
        } catch (Exception e) {
            // ignore
        }
        return -1f;
    }

    public static Double doubleValue(String s) {
        s = s.trim();
        if (s.equals("NaN") || s.isEmpty())
            return -1d;
        try {
            return (double) basic_date_format_s.parse(s).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return (double) basic_date_format_ms.parse(s).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return (double) basic_date_format_ns.parse(s.replace("T", " ").replace("S", "")).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return Double.valueOf(s);
        } catch (Exception e) {
            // ignore
        }
        return -1d;
    }

    public static boolean isDoubleValue(String s) {
        s = s.trim();
        if (s.equals("NaN") || s.isEmpty())
            return true;
        try {
            basic_date_format_s.parse(s).getTime();
            return true;
        } catch (Exception e) {
            // ignore
        }
        try {
            basic_date_format_ms.parse(s).getTime();
            return true;
        } catch (Exception e) {
            // ignore
        }
        try {
            basic_date_format_ns.parse(s.replace("T", " ").replace("S", "")).getTime();
            return true;
        } catch (Exception e) {
            // ignore
        }
        try {
            Double.valueOf(s);
            return true;
        } catch (Exception e) {
            // ignore
        }
        return false;
    }

    public static Long longValue(String s) {
        s = s.trim();
        if (s.equals("NaN") || s.isEmpty())
            return -1L;
        try {
            return basic_date_format_s.parse(s).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return basic_date_format_ms.parse(s).getTime();
        } catch (Exception e) {
            // ignore
        }
        try {
            return Long.valueOf(s);
        } catch (Exception e) {
            // ignore
        }
        return -1L;
    }

    public static String[] split(String line, boolean trim) {
        String[] values = line.indexOf(';') >= 0 ? line.split(";") : line.split(",");
        if (trim) {
            for (int i = 0; i < values.length; i++) {
                values[i] = values[i].trim();
            }
        }
        return values;
    }

    /**
     * Find Double value in format 'name=value'
     * 
     * @param vals
     * @param name
     * @return
     */
    static Double getVal(String[] vals, String name) {
        for (int i = 0; i < vals.length; i++) {
            if (vals[i].startsWith(name + "=")) {
                return doubleValue(vals[i].substring(vals[i].indexOf('=') + 1));
            }
        }
        return null;
    }

    public static boolean isEmpty(String s) {
        return s == null || s.length() == 0 || s.equals("unknown");
    }

    /**
     * Find index of the string inside array
     * 
     * @param header
     * @param name
     * @return
     */
    static int findIndex(String[] header, String name) {
        for (int i = 0; i < header.length; i++) {
            if (header[i].equals(name)) {
                return i;
            }
        }
        return -1;
    }

    public static int count(Collection<Float> values) {
        int count = 0;
        if (values != null)
            for (Float f : values) {
                if (f != null) {
                    count++;
                }
            }
        return count;
    }

    public static Float avg(Collection<Float> values) {
        float sum = 0;
        int count = 0;
        if (values != null)
            for (Float f : values) {
                if (f != null) {
                    count++;
                    sum += f;
                }
            }
        return count > 0 ? sum / count : null;
    }

    public static Float max(Collection<Float> values) {
        float max = 0;
        int count = 0;
        if (values != null)
            for (Float f : values) {
                if (f != null) {
                    if (count == 0 || max < f) {
                        max = f;
                    }
                    count++;
                }
            }
        return count > 0 ? max : null;
    }

    public static Double maxd(Collection<Double> values) {
        double max = 0;
        int count = 0;
        if (values != null)
            for (Double f : values) {
                if (f != null) {
                    if (count == 0 || max < f) {
                        max = f;
                    }
                    count++;
                }
            }
        return count > 0 ? max : null;
    }

    public static String findStringInFile(File file, String str) throws IOException {
        try (Scanner s = new Scanner(new FileInputStream(file))) {
            while (s.hasNext()) {
                String line = s.nextLine();
                int pos = line.indexOf(str);
                if (pos >= 0) {
                    return line;
                }
            }
        }
        return null;
    }

    public static String findStringsInFile(File file, String[] strs) throws IOException {
        try (Scanner s = new Scanner(new FileInputStream(file))) {
            while (s.hasNext()) {
                String line = s.nextLine();
                for (int i = 0; i < strs.length; i++) {
                    int pos = line.indexOf(strs[i]);
                    if (pos >= 0) {
                        return line;
                    }
                }
            }
        }
        return null;
    }
}
