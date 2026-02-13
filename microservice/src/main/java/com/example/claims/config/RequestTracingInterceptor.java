package com.example.claims.config;

import java.util.UUID;

import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class RequestTracingInterceptor implements HandlerInterceptor {

    private static final String TRACE_ID = "traceId";
    private static final String SPAN_ID = "spanId";
    private static final String METHOD = "method";
    private static final String URL = "url";
    private static final String START_TIME = "startTime";

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        // Generate trace and span IDs
        String traceId = UUID.randomUUID().toString();
        String spanId = UUID.randomUUID().toString();

        // Add to MDC for logging
        MDC.put(TRACE_ID, traceId);
        MDC.put(SPAN_ID, spanId);
        MDC.put(METHOD, request.getMethod());
        MDC.put(URL, request.getRequestURI());
        MDC.put(START_TIME, String.valueOf(System.currentTimeMillis()));

        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, Object handler, Exception ex) {
        try {
            // Calculate duration
            String startTimeStr = MDC.get(START_TIME);
            if (startTimeStr != null) {
                long startTime = Long.parseLong(startTimeStr);
                long duration = System.currentTimeMillis() - startTime;
                MDC.put("duration", String.valueOf(duration));
            }

            // Add status code
            MDC.put("status", String.valueOf(response.getStatus()));

            // Log the request completion
            if (ex != null) {
                MDC.put("exception", ex.getClass().getSimpleName() + ": " + ex.getMessage());
            }

        } finally {
            // Clean up MDC
            MDC.remove(TRACE_ID);
            MDC.remove(SPAN_ID);
            MDC.remove(METHOD);
            MDC.remove(URL);
            MDC.remove(START_TIME);
            MDC.remove("duration");
            MDC.remove("status");
            MDC.remove("exception");
        }
    }
}