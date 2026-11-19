package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.entity.Vehicle;
import com.stark_vms_v1.backend.entity.VehicleType;
import com.stark_vms_v1.backend.repository.VehicleRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.validation.ConstraintViolationException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.TransactionSystemException;

import java.time.LocalDateTime;
import java.time.Year;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@DisplayName("Vehicle JPA & Database Integration Tests")
class VehicleIntegrationTest {

    @Autowired
    private VehicleRepository vehicleRepository;

    @PersistenceContext
    private EntityManager entityManager;

    @BeforeEach
    void setUp() {
        vehicleRepository.deleteAll();
    }

    private Vehicle createVehicle(String vehicleNumber) {
        Vehicle vehicle = new Vehicle();
        vehicle.setVehicleNumber(vehicleNumber);
        vehicle.setType(VehicleType.CAR);
        vehicle.setBrand("Toyota");
        vehicle.setModel("Corolla");
        vehicle.setYear(2022);
        return vehicle;
    }

    @Nested
    @DisplayName("Vehicle Number Normalization during JPA Persistence")
    class NormalizationPersistenceTests {

        @Test
        @DisplayName("Normalizes vehicle number on insert (trim and uppercase)")
        void shouldNormalizeVehicleNumberOnInsert() {
            Vehicle vehicle = createVehicle("   dhk-ga-1122   ");
            Vehicle saved = vehicleRepository.save(vehicle);

            Vehicle found = vehicleRepository.findById(saved.getId()).orElseThrow();
            assertEquals("DHK-GA-1122", found.getVehicleNumber());
        }

        @Test
        @DisplayName("Normalizes vehicle number on update (trim and uppercase)")
        void shouldNormalizeVehicleNumberOnUpdate() {
            Vehicle vehicle = createVehicle("DHK-METRO-1111");
            Vehicle saved = vehicleRepository.save(vehicle);

            saved.setVehicleNumber("   dhk-cha-55   ");
            Vehicle updated = vehicleRepository.save(saved);

            Vehicle found = vehicleRepository.findById(updated.getId()).orElseThrow();
            assertEquals("DHK-CHA-55", found.getVehicleNumber());
        }
    }

    @Nested
    @DisplayName("Database Uniqueness Constraint")
    class DatabaseUniquenessTests {

        @Test
        @DisplayName("Fails second insertion when vehicle numbers are identical after normalization")
        void shouldFailDuplicateVehicleNumberInsertion() {
            Vehicle v1 = createVehicle("DHAKA-1234");
            vehicleRepository.save(v1);

            Vehicle v2 = createVehicle("dhaka-1234"); // Normalizes to DHAKA-1234
            assertThrows(DataIntegrityViolationException.class, () -> {
                vehicleRepository.save(v2);
            });
        }

        @Test
        @DisplayName("Fails second insertion when vehicle numbers have leading/trailing whitespace")
        void shouldFailDuplicateVehicleNumberWithWhitespace() {
            Vehicle v1 = createVehicle("DHAKA-5678");
            vehicleRepository.save(v1);

            Vehicle v2 = createVehicle("  DHAKA-5678  ");
            assertThrows(DataIntegrityViolationException.class, () -> {
                vehicleRepository.save(v2);
            });
        }
    }

    @Nested
    @DisplayName("Timestamp Lifecycle Callbacks")
    class TimestampLifecycleTests {

        @Test
        @DisplayName("Automatically sets createdAt and updatedAt on insert")
        void shouldSetTimestampsOnInsert() {
            Vehicle vehicle = createVehicle("TIME-1111");
            Vehicle saved = vehicleRepository.save(vehicle);

            assertNotNull(saved.getCreatedAt(), "createdAt should be set automatically");
            assertNotNull(saved.getUpdatedAt(), "updatedAt should be set automatically");

            Vehicle found = vehicleRepository.findById(saved.getId()).orElseThrow();
            assertNotNull(found.getCreatedAt());
            assertNotNull(found.getUpdatedAt());
        }

        @Test
        @DisplayName("Updates updatedAt on modification while createdAt remains unchanged")
        void shouldUpdateTimestampOnModification() throws InterruptedException {
            Vehicle vehicle = createVehicle("TIME-2222");
            Vehicle saved = vehicleRepository.save(vehicle);

            Vehicle persisted = vehicleRepository.findById(saved.getId()).orElseThrow();
            LocalDateTime initialCreatedAt = persisted.getCreatedAt();
            LocalDateTime initialUpdatedAt = persisted.getUpdatedAt();

            // Wait briefly to ensure a distinct timestamp
            Thread.sleep(50);

            persisted.setBrand("Honda");
            Vehicle updated = vehicleRepository.save(persisted);

            Vehicle reloaded = vehicleRepository.findById(updated.getId()).orElseThrow();
            assertEquals(initialCreatedAt, reloaded.getCreatedAt(), "createdAt must not change on update");
            assertTrue(reloaded.getUpdatedAt().isAfter(initialUpdatedAt), "updatedAt must be updated on modification");
        }

        @Test
        @DisplayName("Prevents modification of createdAt in the database due to updatable=false")
        void shouldNotUpdateCreatedAtInDatabase() {
            Vehicle vehicle = createVehicle("TIME-3333");
            Vehicle saved = vehicleRepository.save(vehicle);

            Vehicle persisted = vehicleRepository.findById(saved.getId()).orElseThrow();
            LocalDateTime initialDbCreatedAt = persisted.getCreatedAt();

            // Attempt to manually change createdAt in Java
            LocalDateTime tamperedTime = LocalDateTime.of(1999, 1, 1, 0, 0);
            persisted.setCreatedAt(tamperedTime);
            persisted.setModel("Civic");
            vehicleRepository.save(persisted);

            // Re-fetch from database to verify database value was not altered
            Vehicle reloaded = vehicleRepository.findById(persisted.getId()).orElseThrow();
            assertEquals(initialDbCreatedAt, reloaded.getCreatedAt(), "createdAt in DB must not be updated");
        }
    }

    @Nested
    @DisplayName("VehicleRepository Methods")
    class RepositoryMethodTests {

        @Test
        @DisplayName("existsByVehicleNumber returns true when exists, false otherwise")
        void testExistsByVehicleNumber() {
            Vehicle vehicle = createVehicle("REPO-1111");
            vehicleRepository.save(vehicle);

            assertTrue(vehicleRepository.existsByVehicleNumber("REPO-1111"));
            assertFalse(vehicleRepository.existsByVehicleNumber("REPO-9999"));
        }

        @Test
        @DisplayName("existsByVehicleNumberAndIdNot correctly handles unique checks on update")
        void testExistsByVehicleNumberAndIdNot() {
            Vehicle v1 = createVehicle("REPO-AAAA");
            v1 = vehicleRepository.save(v1);

            Vehicle v2 = createVehicle("REPO-BBBB");
            v2 = vehicleRepository.save(v2);

            // v1 checking its own number excluding v1's ID should return false (it is itself)
            assertFalse(vehicleRepository.existsByVehicleNumberAndIdNot("REPO-AAAA", v1.getId()));

            // v2 checking if another vehicle has REPO-AAAA excluding v2's ID should return true
            assertTrue(vehicleRepository.existsByVehicleNumberAndIdNot("REPO-AAAA", v2.getId()));

            // Checking a non-existent vehicle number should return false
            assertFalse(vehicleRepository.existsByVehicleNumberAndIdNot("REPO-CCCC", v1.getId()));
        }
    }

    @Nested
    @DisplayName("JPA & Bean Validation Integration")
    class JpaBeanValidationIntegrationTests {

        @Test
        @DisplayName("Persisting vehicle with future year fails Bean Validation at JPA layer")
        void shouldRejectFutureYearOnPersistence() {
            Vehicle vehicle = createVehicle("INV-0001");
            vehicle.setYear(Year.now().getValue() + 5);

            Exception exception = assertThrows(Exception.class, () -> {
                vehicleRepository.save(vehicle);
            });
            assertTrue(
                    exception instanceof ConstraintViolationException ||
                    exception instanceof TransactionSystemException ||
                    exception.getCause() instanceof ConstraintViolationException,
                    "Expected Bean Validation exception on persisting future year"
            );
        }

        @Test
        @DisplayName("Persisting vehicle with year < 1886 fails Bean Validation / DB check constraint")
        void shouldRejectYearBelow1886OnPersistence() {
            Vehicle vehicle = createVehicle("INV-0002");
            vehicle.setYear(1885);

            assertThrows(Exception.class, () -> {
                vehicleRepository.save(vehicle);
            });
        }

        @Test
        @DisplayName("Persisting vehicle with blank vehicle number fails Bean Validation at JPA layer")
        void shouldRejectBlankVehicleNumberOnPersistence() {
            Vehicle vehicle = createVehicle("   ");

            assertThrows(Exception.class, () -> {
                vehicleRepository.save(vehicle);
            });
        }
    }
}
