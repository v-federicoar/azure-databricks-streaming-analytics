package com.microsoft.pnp;

import org.slf4j.MDC;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public class MDCCloseableFactory {
    private class MDCCloseable implements AutoCloseable {
        public MDCCloseable(Map<String, Object> mdc) {
            // Convert Map<String, Object> to Map<String, String>
            Map<String, String> stringMdc = new HashMap<>();
            for (Map.Entry<String, Object> entry : mdc.entrySet()) {
                if (entry.getValue() != null) {
                 stringMdc.put(entry.getKey(), entry.getValue().toString());
                }
            }
            MDC.setContextMap(stringMdc);
        }

        @Override
        public void close() {
            MDC.clear();
        }
    }

    private final Optional<Map<String, Object>> context;

    public MDCCloseableFactory() {
        this(null);
    }

    public MDCCloseableFactory(Map<String, Object> context) {
        this.context = Optional.ofNullable(context);
    }

    public AutoCloseable create(Map<String, Object> mdc) {
        Map<String, Object> newMDC = new HashMap<>();
        this.context.ifPresent(newMDC::putAll);
        newMDC.putAll(mdc);
        return new MDCCloseable(newMDC);
    }
}
