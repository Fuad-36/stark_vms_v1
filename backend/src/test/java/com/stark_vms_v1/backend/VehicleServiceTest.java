package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.dto.VehicleRequest;
import com.stark_vms_v1.backend.dto.VehicleResponse;
import com.stark_vms_v1.backend.entity.Vehicle;
import com.stark_vms_v1.backend.entity.VehicleType;
import com.stark_vms_v1.backend.exception.DuplicateVehicleException;
import com.stark_vms_v1.backend.exception.ResourceNotFoundException;
import com.stark_vms_v1.backend.repository.VehicleRepository;
import com.stark_vms_v1.backend.service.VehicleService;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Sort;

import java.lang.reflect.Proxy;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.BiPredicate;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("VehicleService Unit Tests")
class VehicleServiceTest {

    private StubRepository repositoryStub;
    private VehicleService vehicleService;
    private Vehicle sampleVehicle;

    static class StubRepository {
        Function<Sort, List<Vehicle>> onFindAll = sort -> Collections.emptyList();
        Function<Long, Optional<Vehicle>> onFindById = id -> Optional.empty();
        Predicate<String> onExistsByVehicleNumber = num -> false;
        BiPredicate<String, Long> onExistsByVehicleNumberAndIdNot = (num, id) -> false;
        Function<Vehicle, Vehicle> onSaveAndFlush = v -> v;
        Consumer<Vehicle> onDelete = v -> {};

        final List<String> invocationLog = new ArrayList<>();

        VehicleRepository createProxy() {
            return (VehicleRepository) Proxy.newProxyInstance(
                    VehicleRepository.class.getClassLoader(),
                    new Class<?>[]{VehicleRepository.class},
                    (proxy, method, args) -> {
                        String name = method.getName();
                        invocationLog.add(name);
                        if (name.equals("findAll") && args != null && args.length == 1) {
                            return onFindAll.apply((Sort) args[0]);
                        }
                        if (name.equals("findById")) {
                            return onFindById.apply((Long) args[0]);
                        }
                        if (name.equals("existsByVehicleNumber")) {
                            return onExistsByVehicleNumber.test((String) args[0]);
                        }
                        if (name.equals("existsByVehicleNumberAndIdNot")) {
                            return onExistsByVehicleNumberAndIdNot.test((String) args[0], (Long) args[1]);
                        }
                        if (name.equals("saveAndFlush")) {
                            return onSaveAndFlush.apply((Vehicle) args[0]);
                        }
                        if (name.equals("delete")) {
                            onDelete.accept((Vehicle) args[0]);
                            return null;
                        }
                        if (name.equals("toString")) {
                            return "StubVehicleRepositoryProxy";
                        }
                        if (name.equals("hashCode")) {
                            return System.identityHashCode(proxy);
                        }
                        if (name.equals("equals")) {
                            return proxy == (args != null && args.length > 0 ? args[0] : null);
                        }
                        return null;
                    }
            );
        }
    }

    @BeforeEach
    void setUp() {
        repositoryStub = new StubRepository();
        vehicleService = new VehicleService(repositoryStub.createProxy());

        sampleVehicle = new Vehicle(
                1L,
                "DHK-11-2233",
                VehicleType.CAR,
                "Toyota",
                "Corolla",
                2022,
                LocalDateTime.of(2025, 1, 1, 10, 0),
                LocalDateTime.of(2025, 1, 1, 10, 0)
        );
    }

    @Nested
    @DisplayName("Get All Vehicles")
    class GetAllVehiclesTests {

        @Test
        @DisplayName("Returns list sorted by createdAt DESC and id DESC")
        void shouldReturnSortedListOfVehicles() {
            AtomicReference<Sort> capturedSort = new AtomicReference<>();
            repositoryStub.onFindAll = sort -> {
                capturedSort.set(sort);
                return List.of(sampleVehicle);
            };

            List<VehicleResponse> responses = vehicleService.getAllVehicles();

            assertEquals(1, responses.size());
            VehicleResponse response = responses.get(0);
            assertEquals(sampleVehicle.getId(), response.getId());
            assertEquals(sampleVehicle.getVehicleNumber(), response.getVehicleNumber());
            assertEquals(sampleVehicle.getType(), response.getType());
            assertEquals(sampleVehicle.getBrand(), response.getBrand());
            assertEquals(sampleVehicle.getModel(), response.getModel());
            assertEquals(sampleVehicle.getYear(), response.getYear());
            assertEquals(sampleVehicle.getCreatedAt(), response.getCreatedAt());
            assertEquals(sampleVehicle.getUpdatedAt(), response.getUpdatedAt());

            assertNotNull(capturedSort.get());
            Sort.Order createdAtOrder = capturedSort.get().getOrderFor("createdAt");
            assertNotNull(createdAtOrder);
            assertTrue(createdAtOrder.isDescending());
            Sort.Order idOrder = capturedSort.get().getOrderFor("id");
            assertNotNull(idOrder);
            assertTrue(idOrder.isDescending());
        }

        @Test
        @DisplayName("Returns empty list when no vehicles exist")
        void shouldReturnEmptyListWhenNoVehicles() {
            repositoryStub.onFindAll = sort -> Collections.emptyList();

            List<VehicleResponse> responses = vehicleService.getAllVehicles();

            assertNotNull(responses);
            assertTrue(responses.isEmpty());
        }
    }

    @Nested
    @DisplayName("Get Vehicle By ID")
    class GetVehicleByIdTests {

        @Test
        @DisplayName("Returns vehicle response when found")
        void shouldReturnVehicleWhenFound() {
            repositoryStub.onFindById = id -> Optional.of(sampleVehicle);

            VehicleResponse response = vehicleService.getVehicleById(1L);

            assertNotNull(response);
            assertEquals(1L, response.getId());
            assertEquals("DHK-11-2233", response.getVehicleNumber());
        }

        @Test
        @DisplayName("Throws ResourceNotFoundException when vehicle not found")
        void shouldThrowNotFoundWhenVehicleDoesNotExist() {
            repositoryStub.onFindById = id -> Optional.empty();

            ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class, () -> {
                vehicleService.getVehicleById(999L);
            });
            assertTrue(ex.getMessage().contains("999"));
        }
    }

    @Nested
    @DisplayName("Create Vehicle")
    class CreateVehicleTests {

        @Test
        @DisplayName("Successfully creates vehicle with normalized vehicle number")
        void shouldCreateVehicleSuccessfully() {
            VehicleRequest request = new VehicleRequest("  dhk-ga-1122  ", VehicleType.CAR, "Toyota", "Camry", 2023);
            repositoryStub.onExistsByVehicleNumber = num -> false;

            AtomicReference<Vehicle> savedRef = new AtomicReference<>();
            repositoryStub.onSaveAndFlush = v -> {
                v.setId(2L);
                v.setCreatedAt(LocalDateTime.now());
                v.setUpdatedAt(LocalDateTime.now());
                savedRef.set(v);
                return v;
            };

            VehicleResponse response = vehicleService.createVehicle(request);

            assertNotNull(response);
            assertEquals("DHK-GA-1122", response.getVehicleNumber());
            assertEquals(VehicleType.CAR, response.getType());
            assertEquals("Toyota", response.getBrand());
            assertEquals("Camry", response.getModel());
            assertEquals(2023, response.getYear());
            assertNotNull(response.getCreatedAt());
            assertNotNull(response.getUpdatedAt());

            assertNotNull(savedRef.get());
            assertEquals("DHK-GA-1122", savedRef.get().getVehicleNumber());
        }

        @Test
        @DisplayName("Normalizes vehicle number before checking duplicate")
        void shouldNormalizeBeforeDuplicateCheck() {
            VehicleRequest request = new VehicleRequest("  dhaka-1234  ", VehicleType.BUS, "Hino", "RM2", 2021);
            AtomicReference<String> checkedNum = new AtomicReference<>();
            repositoryStub.onExistsByVehicleNumber = num -> {
                checkedNum.set(num);
                return true;
            };

            DuplicateVehicleException ex = assertThrows(DuplicateVehicleException.class, () -> {
                vehicleService.createVehicle(request);
            });

            assertEquals("DHAKA-1234", checkedNum.get());
            assertEquals("Vehicle number DHAKA-1234 already exists", ex.getMessage());
            assertEquals("DHAKA-1234", ex.getVehicleNumber());
            assertFalse(repositoryStub.invocationLog.contains("saveAndFlush"));
        }

        @Test
        @DisplayName("Translates DataIntegrityViolationException for uk_vehicle_number to DuplicateVehicleException")
        void shouldTranslateDataIntegrityViolationForUniqueConstraint() {
            VehicleRequest request = new VehicleRequest("DHAKA-9999", VehicleType.TRUCK, "Volvo", "FH16", 2020);
            repositoryStub.onExistsByVehicleNumber = num -> false;

            SQLException sqlException = new SQLException("Duplicate entry 'DHAKA-9999' for key 'uk_vehicle_number'", "23000", 1062);
            ConstraintViolationException cve = new ConstraintViolationException("Duplicate", sqlException, "uk_vehicle_number");
            DataIntegrityViolationException dive = new DataIntegrityViolationException("Unique constraint violation", cve);

            repositoryStub.onSaveAndFlush = v -> {
                throw dive;
            };

            DuplicateVehicleException ex = assertThrows(DuplicateVehicleException.class, () -> {
                vehicleService.createVehicle(request);
            });

            assertTrue(ex.getMessage().contains("DHAKA-9999"));
        }

        @Test
        @DisplayName("Propagates unrelated DataIntegrityViolationException without misclassifying")
        void shouldPropagateUnrelatedDataIntegrityViolation() {
            VehicleRequest request = new VehicleRequest("DHAKA-8888", VehicleType.MOTORCYCLE, "Yamaha", "R15", 2022);
            repositoryStub.onExistsByVehicleNumber = num -> false;

            DataIntegrityViolationException dive = new DataIntegrityViolationException("Foreign key violation: fk_user");
            repositoryStub.onSaveAndFlush = v -> {
                throw dive;
            };

            DataIntegrityViolationException ex = assertThrows(DataIntegrityViolationException.class, () -> {
                vehicleService.createVehicle(request);
            });

            assertTrue(ex.getMessage().contains("fk_user"));
        }

        @Test
        @DisplayName("Rejects blank vehicle number in service")
        void shouldRejectBlankVehicleNumberInService() {
            VehicleRequest request = new VehicleRequest("   ", VehicleType.CAR, "Ford", "Focus", 2020);

            assertThrows(IllegalArgumentException.class, () -> {
                vehicleService.createVehicle(request);
            });
        }

        @Test
        @DisplayName("Rejects normalized vehicle number > 20 characters in service")
        void shouldRejectLongVehicleNumberInService() {
            VehicleRequest request = new VehicleRequest("123456789012345678901", VehicleType.CAR, "Ford", "Focus", 2020);

            assertThrows(IllegalArgumentException.class, () -> {
                vehicleService.createVehicle(request);
            });
        }
    }

    @Nested
    @DisplayName("Update Vehicle")
    class UpdateVehicleTests {

        @Test
        @DisplayName("Successfully updates vehicle and preserves original createdAt")
        void shouldUpdateVehicleSuccessfullyAndPreserveCreatedAt() {
            LocalDateTime originalCreatedAt = sampleVehicle.getCreatedAt();

            repositoryStub.onFindById = id -> Optional.of(sampleVehicle);
            repositoryStub.onExistsByVehicleNumberAndIdNot = (num, id) -> false;

            AtomicReference<Vehicle> updatedRef = new AtomicReference<>();
            repositoryStub.onSaveAndFlush = v -> {
                v.setUpdatedAt(LocalDateTime.now());
                updatedRef.set(v);
                return v;
            };

            VehicleRequest updateRequest = new VehicleRequest("  dhk-99-8888  ", VehicleType.BUS, "Scania", "K410", 2024);
            VehicleResponse response = vehicleService.updateVehicle(1L, updateRequest);

            assertNotNull(response);
            assertEquals("DHK-99-8888", response.getVehicleNumber());
            assertEquals(VehicleType.BUS, response.getType());
            assertEquals("Scania", response.getBrand());
            assertEquals("K410", response.getModel());
            assertEquals(2024, response.getYear());
            assertEquals(originalCreatedAt, response.getCreatedAt(), "createdAt must be preserved");

            assertNotNull(updatedRef.get());
            assertEquals("DHK-99-8888", updatedRef.get().getVehicleNumber());
            assertEquals(originalCreatedAt, updatedRef.get().getCreatedAt());
        }

        @Test
        @DisplayName("Updating without changing vehicle number succeeds")
        void shouldSucceedWhenUpdatingWithoutChangingVehicleNumber() {
            repositoryStub.onFindById = id -> Optional.of(sampleVehicle);
            repositoryStub.onExistsByVehicleNumberAndIdNot = (num, id) -> false;
            repositoryStub.onSaveAndFlush = v -> v;

            VehicleRequest updateRequest = new VehicleRequest("dhk-11-2233", VehicleType.CAR, "Toyota", "Corolla Altis", 2023);
            VehicleResponse response = vehicleService.updateVehicle(1L, updateRequest);

            assertEquals("Corolla Altis", response.getModel());
            assertEquals("DHK-11-2233", response.getVehicleNumber());
        }

        @Test
        @DisplayName("Updating with another vehicle's number throws DuplicateVehicleException")
        void shouldThrowDuplicateWhenUpdatingToExistingVehicleNumber() {
            repositoryStub.onFindById = id -> Optional.of(sampleVehicle);
            repositoryStub.onExistsByVehicleNumberAndIdNot = (num, id) -> true;

            VehicleRequest updateRequest = new VehicleRequest("DHK-EXISTING", VehicleType.CAR, "Toyota", "Corolla", 2022);

            DuplicateVehicleException ex = assertThrows(DuplicateVehicleException.class, () -> {
                vehicleService.updateVehicle(1L, updateRequest);
            });

            assertEquals("Vehicle number DHK-EXISTING already exists", ex.getMessage());
            assertFalse(repositoryStub.invocationLog.contains("saveAndFlush"));
        }

        @Test
        @DisplayName("Updating nonexistent vehicle throws ResourceNotFoundException")
        void shouldThrowNotFoundWhenUpdatingNonexistentVehicle() {
            repositoryStub.onFindById = id -> Optional.empty();

            VehicleRequest request = new VehicleRequest("DHK-11-2233", VehicleType.CAR, "Toyota", "Corolla", 2022);
            ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class, () -> {
                vehicleService.updateVehicle(999L, request);
            });

            assertTrue(ex.getMessage().contains("999"));
            assertFalse(repositoryStub.invocationLog.contains("saveAndFlush"));
        }

        @Test
        @DisplayName("Translates DataIntegrityViolationException for uk_vehicle_number during update")
        void shouldTranslateDataIntegrityViolationOnUpdate() {
            repositoryStub.onFindById = id -> Optional.of(sampleVehicle);
            repositoryStub.onExistsByVehicleNumberAndIdNot = (num, id) -> false;

            SQLException sqlException = new SQLException("Duplicate entry 'DHK-RACE' for key 'uk_vehicle_number'", "23000", 1062);
            ConstraintViolationException cve = new ConstraintViolationException("Duplicate", sqlException, "uk_vehicle_number");
            DataIntegrityViolationException dive = new DataIntegrityViolationException("Unique constraint violation", cve);

            repositoryStub.onSaveAndFlush = v -> {
                throw dive;
            };

            VehicleRequest updateRequest = new VehicleRequest("DHK-RACE", VehicleType.CAR, "Ferrari", "488", 2020);

            DuplicateVehicleException ex = assertThrows(DuplicateVehicleException.class, () -> {
                vehicleService.updateVehicle(1L, updateRequest);
            });

            assertTrue(ex.getMessage().contains("DHK-RACE"));
        }
    }

    @Nested
    @DisplayName("Delete Vehicle")
    class DeleteVehicleTests {

        @Test
        @DisplayName("Deletes vehicle when it exists")
        void shouldDeleteExistingVehicle() {
            repositoryStub.onFindById = id -> Optional.of(sampleVehicle);
            AtomicBoolean deleted = new AtomicBoolean(false);
            repositoryStub.onDelete = v -> deleted.set(true);

            vehicleService.deleteVehicle(1L);

            assertTrue(deleted.get());
        }

        @Test
        @DisplayName("Throws ResourceNotFoundException when deleting nonexistent vehicle")
        void shouldThrowNotFoundWhenDeletingNonexistentVehicle() {
            repositoryStub.onFindById = id -> Optional.empty();

            ResourceNotFoundException ex = assertThrows(ResourceNotFoundException.class, () -> {
                vehicleService.deleteVehicle(999L);
            });

            assertTrue(ex.getMessage().contains("999"));
            assertFalse(repositoryStub.invocationLog.contains("delete"));
        }
    }
}
