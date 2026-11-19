package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.controller.VehicleController;
import com.stark_vms_v1.backend.dto.VehicleRequest;
import com.stark_vms_v1.backend.dto.VehicleResponse;
import com.stark_vms_v1.backend.entity.VehicleType;
import com.stark_vms_v1.backend.exception.DuplicateVehicleException;
import com.stark_vms_v1.backend.exception.GlobalExceptionHandler;
import com.stark_vms_v1.backend.exception.ResourceNotFoundException;
import com.stark_vms_v1.backend.service.VehicleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.function.BiFunction;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Supplier;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@DisplayName("VehicleController API Tests")
class VehicleControllerTest {

    private MockMvc mockMvc;
    private StubVehicleService serviceStub;

    static class StubVehicleService extends VehicleService {
        Supplier<List<VehicleResponse>> onGetAll = Collections::emptyList;
        Function<Long, VehicleResponse> onGetById = id -> null;
        Function<VehicleRequest, VehicleResponse> onCreate = req -> null;
        BiFunction<Long, VehicleRequest, VehicleResponse> onUpdate = (id, req) -> null;
        Consumer<Long> onDelete = id -> {};

        public StubVehicleService() {
            super(null);
        }

        @Override
        public List<VehicleResponse> getAllVehicles() {
            return onGetAll.get();
        }

        @Override
        public VehicleResponse getVehicleById(Long id) {
            return onGetById.apply(id);
        }

        @Override
        public VehicleResponse createVehicle(VehicleRequest request) {
            return onCreate.apply(request);
        }

        @Override
        public VehicleResponse updateVehicle(Long id, VehicleRequest request) {
            return onUpdate.apply(id, request);
        }

        @Override
        public void deleteVehicle(Long id) {
            onDelete.accept(id);
        }
    }

    private VehicleResponse createSampleResponse(Long id, String vehicleNumber) {
        return new VehicleResponse(
                id,
                vehicleNumber,
                VehicleType.CAR,
                "Toyota",
                "Corolla",
                2022,
                LocalDateTime.of(2025, 1, 1, 10, 0, 0),
                LocalDateTime.of(2025, 1, 1, 10, 0, 0)
        );
    }

    @BeforeEach
    void setUp() {
        serviceStub = new StubVehicleService();
        VehicleController controller = new VehicleController(serviceStub);

        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Nested
    @DisplayName("GET /api/vehicles")
    class GetAllVehiclesEndpointTests {

        @Test
        @DisplayName("Returns 200 OK with list of vehicles")
        void shouldReturnListOfVehicles() throws Exception {
            serviceStub.onGetAll = () -> List.of(
                    createSampleResponse(1L, "DHK-11-2233"),
                    createSampleResponse(2L, "DHK-33-4455")
            );

            mockMvc.perform(get("/api/vehicles"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$", hasSize(2)))
                    .andExpect(jsonPath("$[0].id").value(1))
                    .andExpect(jsonPath("$[0].vehicleNumber").value("DHK-11-2233"))
                    .andExpect(jsonPath("$[0].type").value("CAR"))
                    .andExpect(jsonPath("$[0].brand").value("Toyota"))
                    .andExpect(jsonPath("$[0].model").value("Corolla"))
                    .andExpect(jsonPath("$[0].year").value(2022))
                    .andExpect(jsonPath("$[0].createdAt").exists())
                    .andExpect(jsonPath("$[0].updatedAt").exists());
        }

        @Test
        @DisplayName("Returns 200 OK with empty array when no vehicles exist")
        void shouldReturnEmptyArrayWhenEmpty() throws Exception {
            serviceStub.onGetAll = Collections::emptyList;

            mockMvc.perform(get("/api/vehicles"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$", hasSize(0)));
        }
    }

    @Nested
    @DisplayName("GET /api/vehicles/{id}")
    class GetVehicleByIdEndpointTests {

        @Test
        @DisplayName("Returns 200 OK with vehicle when found")
        void shouldReturnVehicleById() throws Exception {
            serviceStub.onGetById = id -> createSampleResponse(id, "DHK-11-2233");

            mockMvc.perform(get("/api/vehicles/1"))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.id").value(1))
                    .andExpect(jsonPath("$.vehicleNumber").value("DHK-11-2233"))
                    .andExpect(jsonPath("$.type").value("CAR"))
                    .andExpect(jsonPath("$.brand").value("Toyota"))
                    .andExpect(jsonPath("$.model").value("Corolla"))
                    .andExpect(jsonPath("$.year").value(2022))
                    .andExpect(jsonPath("$.createdAt").exists())
                    .andExpect(jsonPath("$.updatedAt").exists());
        }

        @Test
        @DisplayName("Returns 404 Not Found when vehicle does not exist")
        void shouldReturn404WhenNotFound() throws Exception {
            serviceStub.onGetById = id -> {
                throw new ResourceNotFoundException("Vehicle not found with id: " + id);
            };

            mockMvc.perform(get("/api/vehicles/999"))
                    .andExpect(status().isNotFound())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(404))
                    .andExpect(jsonPath("$.error").value("Not Found"))
                    .andExpect(jsonPath("$.message").value("Vehicle not found with id: 999"))
                    .andExpect(jsonPath("$.fieldErrors").isMap())
                    .andExpect(jsonPath("$.fieldErrors").isEmpty())
                    .andExpect(jsonPath("$.timestamp").exists());
        }
    }

    @Nested
    @DisplayName("POST /api/vehicles")
    class CreateVehicleEndpointTests {

        @Test
        @DisplayName("Returns 201 Created with VehicleResponse on valid request")
        void shouldCreateVehicleSuccessfully() throws Exception {
            serviceStub.onCreate = req -> createSampleResponse(10L, "DHAKA-1234");

            String validJson = """
                    {
                        "vehicleNumber": "  dhaka-1234  ",
                        "type": "CAR",
                        "brand": "Honda",
                        "model": "Civic",
                        "year": 2022
                    }
                    """;

            mockMvc.perform(post("/api/vehicles")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validJson))
                    .andExpect(status().isCreated())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.id").value(10))
                    .andExpect(jsonPath("$.vehicleNumber").value("DHAKA-1234"))
                    .andExpect(jsonPath("$.type").value("CAR"))
                    .andExpect(jsonPath("$.brand").value("Toyota"))
                    .andExpect(jsonPath("$.createdAt").exists())
                    .andExpect(jsonPath("$.updatedAt").exists());
        }

        @Test
        @DisplayName("Returns 409 Conflict with fieldErrors on duplicate vehicle number")
        void shouldReturn409OnDuplicateVehicleNumber() throws Exception {
            serviceStub.onCreate = req -> {
                throw new DuplicateVehicleException("DHAKA-1234", "Vehicle number DHAKA-1234 already exists");
            };

            String duplicateJson = """
                    {
                        "vehicleNumber": "DHAKA-1234",
                        "type": "CAR",
                        "brand": "Honda",
                        "model": "Civic",
                        "year": 2022
                    }
                    """;

            mockMvc.perform(post("/api/vehicles")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(duplicateJson))
                    .andExpect(status().isConflict())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(409))
                    .andExpect(jsonPath("$.error").value("Conflict"))
                    .andExpect(jsonPath("$.message").value("Vehicle number DHAKA-1234 already exists"))
                    .andExpect(jsonPath("$.fieldErrors.vehicleNumber").value("Vehicle number DHAKA-1234 already exists"))
                    .andExpect(jsonPath("$.timestamp").exists());
        }

        @Test
        @DisplayName("Returns 400 Bad Request on validation errors with field-specific errors")
        void shouldReturn400OnValidationFailure() throws Exception {
            String invalidJson = """
                    {
                        "vehicleNumber": "",
                        "type": null,
                        "brand": "",
                        "model": "",
                        "year": 1800
                    }
                    """;

            mockMvc.perform(post("/api/vehicles")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(invalidJson))
                    .andExpect(status().isBadRequest())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.error").value("Bad Request"))
                    .andExpect(jsonPath("$.message").value("Validation failed"))
                    .andExpect(jsonPath("$.fieldErrors.vehicleNumber").exists())
                    .andExpect(jsonPath("$.fieldErrors.type").exists())
                    .andExpect(jsonPath("$.fieldErrors.brand").exists())
                    .andExpect(jsonPath("$.fieldErrors.model").exists())
                    .andExpect(jsonPath("$.fieldErrors.year").exists())
                    .andExpect(jsonPath("$.timestamp").exists());
        }

        @Test
        @DisplayName("Returns 400 Bad Request when vehicleNumber normalized length exceeds 20")
        void shouldReturn400WhenVehicleNumberNormalizedExceeds20() throws Exception {
            String invalidJson = """
                    {
                        "vehicleNumber": "123456789012345678901",
                        "type": "CAR",
                        "brand": "Toyota",
                        "model": "Corolla",
                        "year": 2020
                    }
                    """;

            mockMvc.perform(post("/api/vehicles")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(invalidJson))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.fieldErrors.vehicleNumber").value("Vehicle number must not exceed 20 characters"));
        }

        @Test
        @DisplayName("Returns 400 Bad Request on malformed JSON")
        void shouldReturn400OnMalformedJson() throws Exception {
            String malformedJson = "{ \"vehicleNumber\": \"DHAKA-1234\", ";

            mockMvc.perform(post("/api/vehicles")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(malformedJson))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.error").value("Bad Request"))
                    .andExpect(jsonPath("$.message").exists())
                    .andExpect(jsonPath("$.fieldErrors").isMap())
                    .andExpect(jsonPath("$.fieldErrors").isEmpty());
        }
    }

    @Nested
    @DisplayName("PUT /api/vehicles/{id}")
    class UpdateVehicleEndpointTests {

        @Test
        @DisplayName("Returns 200 OK with updated VehicleResponse")
        void shouldUpdateVehicleSuccessfully() throws Exception {
            serviceStub.onUpdate = (id, req) -> new VehicleResponse(
                    id,
                    "DHAKA-5555",
                    VehicleType.BUS,
                    "Scania",
                    "Touring",
                    2023,
                    LocalDateTime.of(2025, 1, 1, 10, 0),
                    LocalDateTime.now()
            );

            String validJson = """
                    {
                        "vehicleNumber": "DHAKA-5555",
                        "type": "BUS",
                        "brand": "Scania",
                        "model": "Touring",
                        "year": 2023
                    }
                    """;

            mockMvc.perform(put("/api/vehicles/1")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validJson))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.id").value(1))
                    .andExpect(jsonPath("$.vehicleNumber").value("DHAKA-5555"))
                    .andExpect(jsonPath("$.type").value("BUS"))
                    .andExpect(jsonPath("$.brand").value("Scania"))
                    .andExpect(jsonPath("$.model").value("Touring"))
                    .andExpect(jsonPath("$.year").value(2023))
                    .andExpect(jsonPath("$.createdAt").exists())
                    .andExpect(jsonPath("$.updatedAt").exists());
        }

        @Test
        @DisplayName("Returns 404 Not Found when updating nonexistent vehicle")
        void shouldReturn404WhenUpdatingNonexistent() throws Exception {
            serviceStub.onUpdate = (id, req) -> {
                throw new ResourceNotFoundException("Vehicle not found with id: " + id);
            };

            String json = """
                    {
                        "vehicleNumber": "DHAKA-5555",
                        "type": "CAR",
                        "brand": "Ford",
                        "model": "Mustang",
                        "year": 2020
                    }
                    """;

            mockMvc.perform(put("/api/vehicles/999")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.status").value(404))
                    .andExpect(jsonPath("$.message").value("Vehicle not found with id: 999"))
                    .andExpect(jsonPath("$.fieldErrors").isMap())
                    .andExpect(jsonPath("$.fieldErrors").isEmpty());
        }

        @Test
        @DisplayName("Returns 409 Conflict when updating with existing vehicle number")
        void shouldReturn409WhenDuplicateOnUpdate() throws Exception {
            serviceStub.onUpdate = (id, req) -> {
                throw new DuplicateVehicleException("DHAKA-DUPLICATE", "Vehicle number DHAKA-DUPLICATE already exists");
            };

            String json = """
                    {
                        "vehicleNumber": "DHAKA-DUPLICATE",
                        "type": "CAR",
                        "brand": "Ford",
                        "model": "Mustang",
                        "year": 2020
                    }
                    """;

            mockMvc.perform(put("/api/vehicles/1")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.status").value(409))
                    .andExpect(jsonPath("$.error").value("Conflict"))
                    .andExpect(jsonPath("$.fieldErrors.vehicleNumber").value("Vehicle number DHAKA-DUPLICATE already exists"));
        }
    }

    @Nested
    @DisplayName("DELETE /api/vehicles/{id}")
    class DeleteVehicleEndpointTests {

        @Test
        @DisplayName("Returns 204 No Content with empty response body on successful delete")
        void shouldReturn204OnDelete() throws Exception {
            mockMvc.perform(delete("/api/vehicles/1"))
                    .andExpect(status().isNoContent())
                    .andExpect(content().string(""));
        }

        @Test
        @DisplayName("Returns 404 Not Found when deleting nonexistent vehicle")
        void shouldReturn404WhenDeletingNonexistent() throws Exception {
            serviceStub.onDelete = id -> {
                throw new ResourceNotFoundException("Vehicle not found with id: " + id);
            };

            mockMvc.perform(delete("/api/vehicles/999"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.status").value(404))
                    .andExpect(jsonPath("$.message").value("Vehicle not found with id: 999"))
                    .andExpect(jsonPath("$.fieldErrors").isMap())
                    .andExpect(jsonPath("$.fieldErrors").isEmpty());
        }
    }
}
