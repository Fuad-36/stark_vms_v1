package com.stark_vms_v1.backend.exception;

import com.stark_vms_v1.backend.dto.ErrorResponse;
import org.hibernate.exception.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = new LinkedHashMap<>();
        for (FieldError error : ex.getBindingResult().getFieldErrors()) {
            fieldErrors.putIfAbsent(error.getField(), error.getDefaultMessage());
        }

        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                HttpStatus.BAD_REQUEST.getReasonPhrase(),
                "Validation failed",
                fieldErrors
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleHttpMessageNotReadable(HttpMessageNotReadableException ex) {
        log.warn("Malformed JSON or unreadable request: {}", ex.getMessage());
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                HttpStatus.BAD_REQUEST.getReasonPhrase(),
                "Malformed JSON request or invalid input format"
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleResourceNotFound(ResourceNotFoundException ex) {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.NOT_FOUND.value(),
                HttpStatus.NOT_FOUND.getReasonPhrase(),
                ex.getMessage()
        );
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ErrorResponse> handleNoResourceFound(NoResourceFoundException ex) {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.NOT_FOUND.value(),
                HttpStatus.NOT_FOUND.getReasonPhrase(),
                ex.getMessage()
        );
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
    }

    @ExceptionHandler(DuplicateVehicleException.class)
    public ResponseEntity<ErrorResponse> handleDuplicateVehicle(DuplicateVehicleException ex) {
        Map<String, String> fieldErrors = new LinkedHashMap<>();
        fieldErrors.put("vehicleNumber", ex.getMessage());

        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.CONFLICT.value(),
                HttpStatus.CONFLICT.getReasonPhrase(),
                ex.getMessage(),
                fieldErrors
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(errorResponse);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> handleDataIntegrityViolation(DataIntegrityViolationException ex) {
        log.error("Data integrity violation encountered: {}", ex.getMessage());
        if (isVehicleNumberConstraintViolation(ex)) {
            String message = "Vehicle number already exists";
            Map<String, String> fieldErrors = new LinkedHashMap<>();
            fieldErrors.put("vehicleNumber", message);

            ErrorResponse errorResponse = new ErrorResponse(
                    HttpStatus.CONFLICT.value(),
                    HttpStatus.CONFLICT.getReasonPhrase(),
                    message,
                    fieldErrors
            );
            return ResponseEntity.status(HttpStatus.CONFLICT).body(errorResponse);
        }

        if (isUsernameConstraintViolation(ex)) {
            String message = "Username already exists";
            Map<String, String> fieldErrors = new LinkedHashMap<>();
            fieldErrors.put("username", message);

            ErrorResponse errorResponse = new ErrorResponse(
                    HttpStatus.CONFLICT.value(),
                    HttpStatus.CONFLICT.getReasonPhrase(),
                    message,
                    fieldErrors
            );
            return ResponseEntity.status(HttpStatus.CONFLICT).body(errorResponse);
        }

        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase(),
                "An unexpected error occurred"
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ErrorResponse> handleAuthenticationException(AuthenticationException ex) {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.UNAUTHORIZED.value(),
                HttpStatus.UNAUTHORIZED.getReasonPhrase(),
                "Invalid username or password"
        );
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(errorResponse);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex) {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.FORBIDDEN.value(),
                HttpStatus.FORBIDDEN.getReasonPhrase(),
                "Access is denied"
        );
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(errorResponse);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ErrorResponse> handleIllegalArgument(IllegalArgumentException ex) {
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                HttpStatus.BAD_REQUEST.getReasonPhrase(),
                ex.getMessage()
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception ex) {
        log.error("An unexpected error occurred", ex);
        ErrorResponse errorResponse = new ErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase(),
                "An unexpected error occurred"
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }

    private boolean isVehicleNumberConstraintViolation(DataIntegrityViolationException ex) {
        java.util.Set<Throwable> visited = java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<>());
        Throwable current = ex;
        while (current != null && visited.add(current)) {
            if (current instanceof ConstraintViolationException cve) {
                String constraintName = cve.getConstraintName();
                if (constraintName != null && constraintName.toLowerCase(Locale.ROOT).contains("uk_vehicle_number")) {
                    return true;
                }
            }
            String msg = current.getMessage();
            if (msg != null && msg.toLowerCase(Locale.ROOT).contains("uk_vehicle_number")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private boolean isUsernameConstraintViolation(DataIntegrityViolationException ex) {
        java.util.Set<Throwable> visited = java.util.Collections.newSetFromMap(new java.util.IdentityHashMap<>());
        Throwable current = ex;
        while (current != null && visited.add(current)) {
            if (current instanceof ConstraintViolationException cve) {
                String constraintName = cve.getConstraintName();
                if (constraintName != null && constraintName.toLowerCase(Locale.ROOT).contains("uk_users_username")) {
                    return true;
                }
            }
            String msg = current.getMessage();
            if (msg != null && (msg.toLowerCase(Locale.ROOT).contains("uk_users_username") || msg.toLowerCase(Locale.ROOT).contains("username"))) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }
}
