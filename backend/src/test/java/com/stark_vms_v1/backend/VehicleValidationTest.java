package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.entity.Vehicle;
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

@DisplayName("Vehicle Bean Validation & Unit Tests")
class VehicleValidationTest {

    private static Validator validator;

    @BeforeAll
    static void setUpValidator() {
        try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
            validator = factory.getValidator();
        }
    }

    private Vehicle createValidVehicle() {
        Vehicle vehicle = new Vehicle();
        vehicle.setVehicleNumber("DHK-11-2233");
        vehicle.setType(VehicleType.CAR);
        vehicle.setBrand("Toyota");
        vehicle.setModel("Corolla");
        vehicle.setYear(2022);
        return vehicle;
    }

    @Test
    @DisplayName("Valid vehicle produces zero constraint violations")
    void validVehicle_shouldHaveNoViolations() {
        Vehicle vehicle = createValidVehicle();
        Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
        assertTrue(violations.isEmpty(), "Expected valid vehicle to produce no violations");
    }

    @Nested
    @DisplayName("Vehicle Number Validation")
    class VehicleNumberValidationTests {

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {" ", "   ", "\t", "\n"})
        @DisplayName("Rejects null, empty, and whitespace-only vehicle numbers")
        void vehicleNumber_shouldRejectBlank(String blankNumber) {
            Vehicle vehicle = createValidVehicle();
            vehicle.setVehicleNumber(blankNumber);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("vehicleNumber")));
        }

        @Test
        @DisplayName("Accepts vehicle number with exactly 20 characters")
        void vehicleNumber_shouldAcceptMaxLength20() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setVehicleNumber("12345678901234567890"); // exactly 20 chars

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects vehicle number exceeding 20 characters")
        void vehicleNumber_shouldRejectLengthGreaterThan20() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setVehicleNumber("123456789012345678901"); // 21 chars

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("vehicleNumber")));
        }
    }

    @Nested
    @DisplayName("Vehicle Type Validation")
    class VehicleTypeValidationTests {

        @Test
        @DisplayName("Rejects null vehicle type")
        void vehicleType_shouldRejectNull() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setType(null);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("type")));
        }

        @Test
        @DisplayName("VehicleType enum contains all required values")
        void vehicleTypeEnum_containsAllRequiredValues() {
            assertNotNull(VehicleType.valueOf("CAR"));
            assertNotNull(VehicleType.valueOf("BUS"));
            assertNotNull(VehicleType.valueOf("TRUCK"));
            assertNotNull(VehicleType.valueOf("MOTORCYCLE"));
            assertEquals(4, VehicleType.values().length);
        }
    }

    @Nested
    @DisplayName("Brand Validation")
    class BrandValidationTests {

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {" ", "   "})
        @DisplayName("Rejects null, empty, and whitespace-only brand")
        void brand_shouldRejectBlank(String blankBrand) {
            Vehicle vehicle = createValidVehicle();
            vehicle.setBrand(blankBrand);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("brand")));
        }

        @Test
        @DisplayName("Accepts brand with max 50 characters")
        void brand_shouldAcceptMaxLength50() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setBrand("A".repeat(50));

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects brand exceeding 50 characters")
        void brand_shouldRejectLengthGreaterThan50() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setBrand("A".repeat(51));

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("brand")));
        }
    }

    @Nested
    @DisplayName("Model Validation")
    class ModelValidationTests {

        @ParameterizedTest
        @NullAndEmptySource
        @ValueSource(strings = {" ", "   "})
        @DisplayName("Rejects null, empty, and whitespace-only model")
        void model_shouldRejectBlank(String blankModel) {
            Vehicle vehicle = createValidVehicle();
            vehicle.setModel(blankModel);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("model")));
        }

        @Test
        @DisplayName("Accepts model with max 50 characters")
        void model_shouldAcceptMaxLength50() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setModel("M".repeat(50));

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertTrue(violations.isEmpty());
        }

        @Test
        @DisplayName("Rejects model exceeding 50 characters")
        void model_shouldRejectLengthGreaterThan50() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setModel("M".repeat(51));

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("model")));
        }
    }

    @Nested
    @DisplayName("Dynamic Year Validation")
    class YearValidationTests {

        @Test
        @DisplayName("Rejects null year")
        void year_shouldRejectNull() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setYear(null);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("year")));
        }

        @Test
        @DisplayName("Rejects year earlier than 1886 (boundary: 1885)")
        void year_shouldRejectBelow1886() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setYear(1885);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("year")));
        }

        @Test
        @DisplayName("Accepts year 1886 (lower boundary)")
        void year_shouldAccept1886() {
            Vehicle vehicle = createValidVehicle();
            vehicle.setYear(1886);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertTrue(violations.isEmpty(), "1886 should be valid");
        }

        @Test
        @DisplayName("Accepts dynamic current year (upper boundary)")
        void year_shouldAcceptCurrentYear() {
            Vehicle vehicle = createValidVehicle();
            int currentYear = Year.now().getValue();
            vehicle.setYear(currentYear);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertTrue(violations.isEmpty(), "Current year should be valid");
        }

        @Test
        @DisplayName("Rejects future year dynamically (current year + 1)")
        void year_shouldRejectFutureYear() {
            Vehicle vehicle = createValidVehicle();
            int futureYear = Year.now().getValue() + 1;
            vehicle.setYear(futureYear);

            Set<ConstraintViolation<Vehicle>> violations = validator.validate(vehicle);
            assertFalse(violations.isEmpty());
            assertTrue(violations.stream().anyMatch(v -> v.getPropertyPath().toString().equals("year")));
        }
    }
}
