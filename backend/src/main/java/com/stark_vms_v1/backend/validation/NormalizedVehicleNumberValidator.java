package com.stark_vms_v1.backend.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.util.Locale;

public class NormalizedVehicleNumberValidator implements ConstraintValidator<NormalizedVehicleNumber, String> {

    private int max;

    @Override
    public void initialize(NormalizedVehicleNumber constraintAnnotation) {
        this.max = constraintAnnotation.max();
    }

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) {
            return true;
        }
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        if (normalized.isEmpty()) {
            return true;
        }
        return normalized.length() <= max;
    }
}
