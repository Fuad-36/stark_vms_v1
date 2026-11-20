package com.stark_vms_v1.backend.config;

import com.stark_vms_v1.backend.dto.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
public class CustomAccessDeniedHandler implements AccessDeniedHandler {

    private final SecurityJsonResponseWriter jsonResponseWriter;

    public CustomAccessDeniedHandler(SecurityJsonResponseWriter jsonResponseWriter) {
        this.jsonResponseWriter = jsonResponseWriter;
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response, AccessDeniedException accessDeniedException) throws IOException {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.FORBIDDEN.value(),
                HttpStatus.FORBIDDEN.getReasonPhrase(),
                "Access is denied"
        );
        jsonResponseWriter.writeErrorResponse(response, HttpStatus.FORBIDDEN, errorResponse);
    }
}
