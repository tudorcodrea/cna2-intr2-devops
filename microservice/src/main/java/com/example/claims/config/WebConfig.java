package com.example.claims.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final RequestTracingInterceptor requestTracingInterceptor;

    @Autowired
    public WebConfig(RequestTracingInterceptor requestTracingInterceptor) {
        this.requestTracingInterceptor = requestTracingInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(requestTracingInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns("/api/v1/claims/health/**");
    }
}