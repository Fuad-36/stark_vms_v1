package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.entity.UserRole;
import com.stark_vms_v1.backend.entity.Vehicle;
import com.stark_vms_v1.backend.entity.VehicleType;
import com.stark_vms_v1.backend.repository.UserRepository;
import com.stark_vms_v1.backend.repository.VehicleRepository;
import com.stark_vms_v1.backend.service.JwtService;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.hamcrest.Matchers.*;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@DisplayName("Security & JWT Integration Tests")
class SecurityIntegrationTest {

    @Autowired
    private WebApplicationContext context;

    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private VehicleRepository vehicleRepository;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Value("${app.jwt.secret}")
    private String jwtSecret;

    private User adminUser;
    private String adminToken;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(springSecurity())
                .build();

        vehicleRepository.deleteAll();
        userRepository.deleteAll();

        adminUser = new User("admin", passwordEncoder.encode("Admin@123"), UserRole.ADMIN);
        adminUser = userRepository.save(adminUser);
        adminToken = jwtService.generateToken(adminUser);
    }

    @Nested
    @DisplayName("Public Endpoints Tests")
    class PublicEndpointsTests {

        @Test
        @DisplayName("POST /api/auth/login is publicly accessible without token")
        void shouldAllowLoginWithoutToken() throws Exception {
            String loginJson = """
                    {
                        "username": "admin",
                        "password": "Admin@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(loginJson))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.token").isString())
                    .andExpect(jsonPath("$.tokenType").value("Bearer"))
                    .andExpect(jsonPath("$.expiresIn").value(3600))
                    .andExpect(jsonPath("$.username").value("admin"));
        }

        @Test
        @DisplayName("Normalizes username on login (case insensitivity and trimming)")
        void shouldAllowLoginWithNormalizedUsername() throws Exception {
            String loginJson = """
                    {
                        "username": "   ADMIN   ",
                        "password": "Admin@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(loginJson))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.token").isString())
                    .andExpect(jsonPath("$.username").value("admin"));
        }

        @Test
        @DisplayName("GET /api/health is publicly accessible without token")
        void shouldAllowHealthEndpointWithoutToken() throws Exception {
            mockMvc.perform(get("/api/health"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("UP"));
        }

        @Test
        @DisplayName("OPTIONS preflight requests are permitted without authentication and return CORS headers")
        void shouldAllowCorsPreflightWithoutAuthentication() throws Exception {
            mockMvc.perform(options("/api/vehicles")
                            .header("Origin", "http://localhost:3000")
                            .header("Access-Control-Request-Method", "GET")
                            .header("Access-Control-Request-Headers", "Authorization,Content-Type"))
                    .andExpect(status().isOk())
                    .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:3000"))
                    .andExpect(header().string("Access-Control-Allow-Methods", containsString("GET")));
        }
    }

    @Nested
    @DisplayName("Authentication Failures Tests")
    class AuthenticationFailuresTests {

        @Test
        @DisplayName("Missing token on protected endpoint returns 401 JSON ErrorResponse")
        void shouldReturn401WhenTokenIsMissing() throws Exception {
            mockMvc.perform(get("/api/vehicles"))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"))
                    .andExpect(jsonPath("$.message").exists())
                    .andExpect(jsonPath("$.timestamp").exists());
        }

        @Test
        @DisplayName("Invalid Bearer header returns 401 JSON ErrorResponse")
        void shouldReturn401OnInvalidBearerHeader() throws Exception {
            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Basic dXNlcjpwYXNz"))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"));
        }

        @Test
        @DisplayName("Empty Bearer token returns 401 JSON ErrorResponse")
        void shouldReturn401OnEmptyBearerToken() throws Exception {
            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer "))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"));
        }

        @Test
        @DisplayName("Malformed token returns 401 JSON ErrorResponse")
        void shouldReturn401OnMalformedToken() throws Exception {
            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer not.a.valid.jwt"))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"));
        }

        @Test
        @DisplayName("Expired token returns 401 JSON ErrorResponse")
        void shouldReturn401OnExpiredToken() throws Exception {
            SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
            Date past = new Date(System.currentTimeMillis() - 10000);
            Date olderPast = new Date(past.getTime() - 10000);

            String expiredToken = Jwts.builder()
                    .subject(String.valueOf(adminUser.getId()))
                    .claim("role", "ADMIN")
                    .issuedAt(olderPast)
                    .expiration(past)
                    .signWith(key, Jwts.SIG.HS256)
                    .compact();

            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + expiredToken))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"));
        }

        @Test
        @DisplayName("Invalid signature returns 401 JSON ErrorResponse")
        void shouldReturn401OnInvalidSignature() throws Exception {
            SecretKey wrongKey = Keys.hmacShaKeyFor("a-completely-different-signing-key-for-testing-tampering".getBytes(StandardCharsets.UTF_8));

            String forgedToken = Jwts.builder()
                    .subject(String.valueOf(adminUser.getId()))
                    .claim("role", "ADMIN")
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(wrongKey, Jwts.SIG.HS256)
                    .compact();

            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + forgedToken))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"));
        }

        @Test
        @DisplayName("Deleted user with an otherwise valid token receives 401 JSON ErrorResponse")
        void shouldReturn401WhenUserIsDeleted() throws Exception {
            // Token was validly generated for adminUser
            // Delete user from database
            userRepository.deleteById(adminUser.getId());

            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"));
        }
    }

    @Nested
    @DisplayName("Authorization & Role Tests")
    class AuthorizationAndRoleTests {

        @Test
        @DisplayName("Valid token with ADMIN role grants access to protected endpoints")
        void shouldGrantAccessToAdmin() throws Exception {
            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON));
        }

        @Test
        @DisplayName("Non-ADMIN user receives HTTP 403 Forbidden with JSON ErrorResponse")
        void shouldReturn403ForNonAdminUser() throws Exception {
            User regularUser = new User("regularuser", passwordEncoder.encode("Pass@123"), UserRole.USER);
            regularUser = userRepository.save(regularUser);

            String regularToken = jwtService.generateToken(regularUser);

            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + regularToken))
                    .andExpect(status().isForbidden())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(403))
                    .andExpect(jsonPath("$.error").value("Forbidden"))
                    .andExpect(jsonPath("$.message").value("Access is denied"));
        }

        @Test
        @DisplayName("User's updated role in database is reflected on subsequent requests")
        void shouldReflectRoleUpdateImmediately() throws Exception {
            // adminToken was generated with ADMIN role claim
            // Now update the user in DB to USER
            adminUser.setRole(UserRole.USER);
            userRepository.save(adminUser);

            // Using the SAME previously-issued token: database role must determine authorities!
            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isForbidden())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(403))
                    .andExpect(jsonPath("$.error").value("Forbidden"));
        }
    }

    @Nested
    @DisplayName("Vehicle API Regression Tests With Authentication")
    class VehicleApiRegressionTests {

        @Test
        @DisplayName("Unauthenticated requests to all vehicle endpoints are rejected with 401")
        void shouldRejectUnauthenticatedVehicleRequests() throws Exception {
            mockMvc.perform(get("/api/vehicles")).andExpect(status().isUnauthorized());
            mockMvc.perform(get("/api/vehicles/1")).andExpect(status().isUnauthorized());
            mockMvc.perform(post("/api/vehicles")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{}"))
                    .andExpect(status().isUnauthorized());
            mockMvc.perform(put("/api/vehicles/1")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{}"))
                    .andExpect(status().isUnauthorized());
            mockMvc.perform(delete("/api/vehicles/1")).andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("Authenticated ADMIN can perform full vehicle CRUD operations")
        void shouldAllowAdminVehicleCrud() throws Exception {
            // 1. CREATE
            String createJson = """
                    {
                        "vehicleNumber": "DHK-11-2233",
                        "type": "CAR",
                        "brand": "Toyota",
                        "model": "Corolla",
                        "year": 2022
                    }
                    """;

            String responseBody = mockMvc.perform(post("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(createJson))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.id").exists())
                    .andExpect(jsonPath("$.vehicleNumber").value("DHK-11-2233"))
                    .andReturn().getResponse().getContentAsString();

            // Extract created vehicle ID
            Long vehicleId = com.jayway.jsonpath.JsonPath.parse(responseBody).read("$.id", Long.class);

            // 2. GET ALL
            mockMvc.perform(get("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$", hasSize(1)))
                    .andExpect(jsonPath("$[0].vehicleNumber").value("DHK-11-2233"));

            // 3. GET BY ID
            mockMvc.perform(get("/api/vehicles/" + vehicleId)
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.id").value(vehicleId))
                    .andExpect(jsonPath("$.brand").value("Toyota"));

            // 4. UPDATE
            String updateJson = """
                    {
                        "vehicleNumber": "DHK-11-2233",
                        "type": "TRUCK",
                        "brand": "Toyota",
                        "model": "Hilux",
                        "year": 2023
                    }
                    """;

            mockMvc.perform(put("/api/vehicles/" + vehicleId)
                            .header("Authorization", "Bearer " + adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(updateJson))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.type").value("TRUCK"))
                    .andExpect(jsonPath("$.model").value("Hilux"))
                    .andExpect(jsonPath("$.year").value(2023));

            // 5. DELETE
            mockMvc.perform(delete("/api/vehicles/" + vehicleId)
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isNoContent());

            // 6. VERIFY NOT FOUND AFTER DELETE
            mockMvc.perform(get("/api/vehicles/" + vehicleId)
                            .header("Authorization", "Bearer " + adminToken))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.status").value(404));
        }

        @Test
        @DisplayName("Preserves vehicle business validation rules for authenticated ADMIN requests")
        void shouldPreserveVehicleValidation() throws Exception {
            String invalidVehicleJson = """
                    {
                        "vehicleNumber": "",
                        "type": "CAR",
                        "brand": "",
                        "model": "Corolla",
                        "year": 1800
                    }
                    """;

            mockMvc.perform(post("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(invalidVehicleJson))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.fieldErrors.vehicleNumber").exists())
                    .andExpect(jsonPath("$.fieldErrors.brand").exists())
                    .andExpect(jsonPath("$.fieldErrors.year").exists());
        }

        @Test
        @DisplayName("Preserves duplicate vehicle number constraint for authenticated ADMIN requests")
        void shouldPreserveDuplicateVehicleConstraint() throws Exception {
            Vehicle existing = new Vehicle("DHAKA-9999", VehicleType.CAR, "Nissan", "Sunny", 2020);
            vehicleRepository.save(existing);

            String duplicateJson = """
                    {
                        "vehicleNumber": "dhaka-9999",
                        "type": "CAR",
                        "brand": "Nissan",
                        "model": "Sunny",
                        "year": 2020
                    }
                    """;

            mockMvc.perform(post("/api/vehicles")
                            .header("Authorization", "Bearer " + adminToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(duplicateJson))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.status").value(409))
                    .andExpect(jsonPath("$.fieldErrors.vehicleNumber").exists());
        }
    }
}
