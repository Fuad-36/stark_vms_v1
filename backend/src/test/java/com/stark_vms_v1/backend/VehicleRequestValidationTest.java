package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.dto.VehicleRequest;
import com.stark_vms_v1.backend.entity.VehicleType;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import java.time.Year;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("VehicleRequest Bean Validation Tests")
class VehicleRequestValidationTest {

    private static Validator validator;

    @BeforeAll
    static void setUpValidator() {
        try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
            validator = factory.getValidator();
        }
    }

    private VehicleRequest createValidRequest() {
        return new VehicleRequest(
                "DHK-11-2233",
                VehicleType.CAR,
                "Toyota",
                "Corolla",
                2022
        );
    }

    @Test
    @DisplayName("Valid vehicle request produces zero constraint violations")
    void validRequest_shouldHaveNoViolations() {
        VehicleRequest request = createValidRequest();
        Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
        assertTrue(violations.isEmpty(), "Expected valid request to produce no violations");
    }

    @Nested
    @DisplayName("Vehicle Number Validation Rules")
    class VehicleNumberValidationTests {

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {" ", "   ", "\t", "\n"})
        @DisplayName("Rejects null, empty, and whitespace-only vehicle numbers")
        void shouldRejectBlankVehicleNumber(String blank) {
            VehicleRequest request = createValidRequest();
            request.setVehicleNumber(blank);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("vehicleNumber")));
        }

        @Test
        @DisplayName("Accepts vehicle number with whitespace where normalized length <= 20")
        void shouldAcceptWhitespaceWhenNormalizedLengthUnder20() {
            VehicleRequest request = createValidRequest();
            // Raw is 14 chars with spaces, normalized "DHAKA-1234" is 10 chars
            request.setVehicleNumber("  dhaka-1234  ");

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Accepts exactly 20 characters after trimming")
        void shouldAcceptExactly20Characters() {
            VehicleRequest request = createValidRequest();
            request.setVehicleNumber("  12345678901234567890  ");

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects normalized vehicle number longer than 20 characters")
        void shouldRejectNormalizedLengthGreaterThan20() {
            VehicleRequest request = createValidRequest();
            request.setVehicleNumber("  123456789012345678901  "); // 21 chars normalized

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("vehicleNumber")));
        }
    }

    @Nested
    @DisplayName("Vehicle Type Validation Rules")
    class VehicleTypeValidationTests {

        @Test
        @DisplayName("Rejects null vehicle type")
        void shouldRejectNullType() {
            VehicleRequest request = createValidRequest();
            request.setType(null);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("type")));
        }
    }

    @Nested
    @DisplayName("Brand Validation Rules")
    class BrandValidationTests {

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {" ", "   "})
        @DisplayName("Rejects blank brand")
        void shouldRejectBlankBrand(String blank) {
            VehicleRequest request = createValidRequest();
            request.setBrand(blank);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("brand")));
        }

        @Test
        @DisplayName("Accepts brand up to 50 characters")
        void shouldAcceptBrandMaxLength50() {
            VehicleRequest request = createValidRequest();
            request.setBrand("B".repeat(50));

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects brand exceeding 50 characters")
        void shouldRejectBrandOver50() {
            VehicleRequest request = createValidRequest();
            request.setBrand("B".repeat(51));

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("brand")));
        }
    }

    @Nested
    @DisplayName("Model Validation Rules")
    class ModelValidationTests {

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {" ", "   "})
        @DisplayName("Rejects blank model")
        void shouldRejectBlankModel(String blank) {
            VehicleRequest request = createValidRequest();
            request.setModel(blank);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("model")));
        }

        @Test
        @DisplayName("Accepts model up to 50 characters")
        void shouldAcceptModelMaxLength50() {
            VehicleRequest request = createValidRequest();
            request.setModel("M".repeat(50));

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects model exceeding 50 characters")
        void shouldRejectModelOver50() {
            VehicleRequest request = createValidRequest();
            request.setModel("M".repeat(51));

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("model")));
        }
    }

    @Nested
    @DisplayName("Year Validation Rules")
    class YearValidationTests {

        @Test
        @DisplayName("Rejects null year")
        void shouldRejectNullYear() {
            VehicleRequest request = createValidRequest();
            request.setYear(null);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("year")));
        }

        @Test
        @DisplayName("Rejects year below 1886")
        void shouldRejectYearBelow1886() {
            VehicleRequest request = createValidRequest();
            request.setYear(1885);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("year")));
        }

        @Test
        @DisplayName("Accepts year 1886")
        void shouldAccept1886() {
            VehicleRequest request = createValidRequest();
            request.setYear(1886);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Accepts current year")
        void shouldAcceptCurrentYear() {
            VehicleRequest request = createValidRequest();
            request.setYear(Year.now().getValue());

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects future year")
        void shouldRejectFutureYear() {
            VehicleRequest request = createValidRequest();
            request.setYear(Year.now().getValue() + 1);

            Set<ConstraintViolation<VehicleRequest>> violations = validator.validate(request);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("year")));
        }
    }
}
