package org.tussleframework.tools;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * Unit test for simple App.
 */
class AppTest {

    @Test
    void testApp() {
        assertTrue(true);
    }

    @Test
    void testStr() {
        String name1 = "histogram_100_0_processed";
        assertTrue(name1.contains("processed"));
        String name2 = "histogram_100_0.hgrm";
        assertTrue(!name2.contains("processed"));
    }
}
