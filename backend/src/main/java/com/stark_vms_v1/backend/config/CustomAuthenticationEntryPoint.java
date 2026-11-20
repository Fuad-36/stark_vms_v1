package com.stark_vms_v1.backend.config;

import com.stark_vms_v1.backend.dto.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
public class CustomAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final SecurityJsonResponseWriter jsonResponseWriter;

    public CustomAuthenticationEntryPoint(SecurityJsonResponseWriter jsonResponseWriter) {
        this.jsonResponseWriter = jsonResponseWriter;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException authException) throws IOException {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.UNAUTHORIZED.value(),
                HttpStatus.UNAUTHORIZED.getReasonPhrase(),
                "Full authentication is required to access this resource"
        );
        jsonResponseWriter.writeErrorResponse(response, HttpStatus.UNAUTHORIZED, errorResponse);
    }
}
