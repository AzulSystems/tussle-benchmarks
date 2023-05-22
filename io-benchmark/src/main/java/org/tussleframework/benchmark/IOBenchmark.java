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

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicInteger;

import org.tussleframework.RunnableWithError;
import org.tussleframework.TussleException;
import org.tussleframework.WlBenchmark;
import org.tussleframework.WlConfig;
import org.tussleframework.tools.FormatTool;

public class IOBenchmark extends WlBenchmark {

    private ArrayList<FileChannel> largeFiles = new ArrayList<>();
    private ArrayList<File> testFiles = new ArrayList<>();

    @Override
    public Class<? extends WlConfig> getConfigClass() {
        return IOBenchmarkConfig.class;
    }

    @Override
    public void init(String[] args) throws TussleException {
        super.init(args);
        IOBenchmarkConfig config = (IOBenchmarkConfig) getConfig();
        File dir = new File(config.filesDir);
        dir.mkdirs();
        log("Creating %s...", FormatTool.withS(config.largeCount, "large file"));
        for (int i = 0; i < config.largeCount; i++) {
            largeFiles.add(writeAndGet(i + 1, config.largeSize * 1024 * 1024));
        }
    }

    @Override
    public void cleanup() {
        super.cleanup();
        largeFiles.forEach(fc -> {
            try {
                fc.close();
            } catch (IOException e) {
            }
        });
        testFiles.forEach(File::delete);
    }

    @Override
    public RunnableWithError getWorkload() {
        AtomicInteger iterartions = new AtomicInteger(0);
        return () -> {
            IOBenchmarkConfig config = (IOBenchmarkConfig) getConfig();
            writeAndCloseSimple(iterartions.incrementAndGet() % 10, config.smallSize, config.flush);
            return true;
        };
    }

    @Override
    public String getName() {
        return "io-tussle";
    }

    @Override
    public String getOperationName() {
        return "force";
    }

    protected ByteBuffer bufferOf(int size) {
        ByteBuffer buffer = ByteBuffer.allocate(size);
        for (int i = 0; i < size; i++) {
            buffer.put((byte) i);
        }
        buffer.flip();
        return buffer;
    }

    public static void writeUnsignedInt(ByteBuffer buffer, int index, long value) {
        buffer.putInt(index, (int) (value & 0xffffffffL));
    }

    protected void writeAndCloseSimple(int n, int size, boolean flush) {
        writeAndClose(n, flush, bufferOf(size));
    }

    protected void writeAndClose(int n, boolean flush, ByteBuffer buffer) {
        IOBenchmarkConfig config = (IOBenchmarkConfig) getConfig();
        File file = new File(config.filesDir, "ioworkload_file_closed_" + n + ".tmp");
        try (FileChannel fileChannel = FileChannel.open(file.toPath(), StandardOpenOption.CREATE, StandardOpenOption.WRITE)) {
            testFiles.add(file);
            fileChannel.write(buffer);
            if (flush) {
                fileChannel.force(true);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    protected FileChannel writeAndGet(int n, int size) {
        IOBenchmarkConfig config = (IOBenchmarkConfig) getConfig();
        File file = new File(config.filesDir, "ioworkload_file_opened_" + n + ".tmp");
        FileChannel fileChannel = null;
        final int CN = 1024 * 64;
        try {
            fileChannel = FileChannel.open(file.toPath(), StandardOpenOption.CREATE, StandardOpenOption.WRITE);
            testFiles.add(file);
            while (size > 0) {
                int chunkSize = size > CN ? CN : size;
                fileChannel.write(bufferOf(chunkSize));
                size -= chunkSize;
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return fileChannel;
    }
}
