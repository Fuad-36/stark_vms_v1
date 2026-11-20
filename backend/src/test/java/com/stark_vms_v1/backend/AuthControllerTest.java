package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.controller.AuthController;
import com.stark_vms_v1.backend.dto.LoginRequest;
import com.stark_vms_v1.backend.dto.LoginResponse;
import com.stark_vms_v1.backend.exception.GlobalExceptionHandler;
import com.stark_vms_v1.backend.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.function.Function;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@DisplayName("AuthController API Tests")
class AuthControllerTest {

    private MockMvc mockMvc;
    private StubAuthService authServiceStub;

    static class StubAuthService extends AuthService {
        Function<LoginRequest, LoginResponse> onLogin = req -> null;

        public StubAuthService() {
            super(null, null, null);
        }

        @Override
        public LoginResponse login(LoginRequest request) {
            return onLogin.apply(request);
        }
    }

    @BeforeEach
    void setUp() {
        authServiceStub = new StubAuthService();
        AuthController controller = new AuthController(authServiceStub);
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Nested
    @DisplayName("POST /api/auth/login")
    class LoginEndpointTests {

        @Test
        @DisplayName("Returns 200 OK with token and Bearer tokenType on valid credentials")
        void shouldReturnTokenOnValidCredentials() throws Exception {
            authServiceStub.onLogin = req -> new LoginResponse(
                    "mock-valid-jwt-token",
                    "Bearer",
                    3600,
                    req.getUsername().trim().toLowerCase()
            );

            String requestBody = """
                    {
                        "username": "admin",
                        "password": "Admin@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(requestBody))
                    .andExpect(status().isOk())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.token").value("mock-valid-jwt-token"))
                    .andExpect(jsonPath("$.tokenType").value("Bearer"))
                    .andExpect(jsonPath("$.expiresIn").value(3600))
                    .andExpect(jsonPath("$.username").value("admin"));
        }

        @Test
        @DisplayName("Returns 401 Unauthorized with generic message on wrong password")
        void shouldReturn401OnWrongPassword() throws Exception {
            authServiceStub.onLogin = req -> {
                throw new BadCredentialsException("Invalid username or password");
            };

            String requestBody = """
                    {
                        "username": "admin",
                        "password": "WrongPassword@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(requestBody))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"))
                    .andExpect(jsonPath("$.message").value("Invalid username or password"))
                    .andExpect(jsonPath("$.timestamp").exists());
        }

        @Test
        @DisplayName("Returns 401 Unauthorized with same generic message on unknown username")
        void shouldReturn401OnUnknownUser() throws Exception {
            authServiceStub.onLogin = req -> {
                throw new BadCredentialsException("Invalid username or password");
            };

            String requestBody = """
                    {
                        "username": "unknown_user",
                        "password": "AnyPassword@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(requestBody))
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(401))
                    .andExpect(jsonPath("$.error").value("Unauthorized"))
                    .andExpect(jsonPath("$.message").value("Invalid username or password"));
        }

        @Test
        @DisplayName("Returns 400 Bad Request on missing username")
        void shouldReturn400OnMissingUsername() throws Exception {
            String requestBody = """
                    {
                        "password": "Password@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(requestBody))
                    .andExpect(status().isBadRequest())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.error").value("Bad Request"))
                    .andExpect(jsonPath("$.fieldErrors.username").exists());
        }

        @Test
        @DisplayName("Returns 400 Bad Request on blank username")
        void shouldReturn400OnBlankUsername() throws Exception {
            String requestBody = """
                    {
                        "username": "   ",
                        "password": "Password@123"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(requestBody))
                    .andExpect(status().isBadRequest())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.fieldErrors.username").exists());
        }

        @Test
        @DisplayName("Returns 400 Bad Request on missing password")
        void shouldReturn400OnMissingPassword() throws Exception {
            String requestBody = """
                    {
                        "username": "admin"
                    }
                    """;

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(requestBody))
                    .andExpect(status().isBadRequest())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.fieldErrors.password").exists());
        }

        @Test
        @DisplayName("Returns 400 Bad Request on malformed JSON")
        void shouldReturn400OnMalformedJson() throws Exception {
            String malformedJson = "{ username: admin, ";

            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(malformedJson))
                    .andExpect(status().isBadRequest())
                    .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                    .andExpect(jsonPath("$.status").value(400))
                    .andExpect(jsonPath("$.message").value("Malformed JSON request or invalid input format"));
        }
    }
}
