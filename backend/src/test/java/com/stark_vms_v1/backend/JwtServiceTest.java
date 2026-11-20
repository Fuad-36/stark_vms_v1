package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.entity.UserRole;
import com.stark_vms_v1.backend.service.JwtService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.SignatureException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("JwtService Unit Tests")
class JwtServiceTest {

    private static final String TEST_SECRET = "super-secret-jwt-signing-key-for-unit-testing-32-chars-min";
    private static final long EXPIRATION_SECONDS = 3600;

    private JwtService jwtService;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService(TEST_SECRET, EXPIRATION_SECONDS);
        jwtService.init();
    }

    @Nested
    @DisplayName("Startup Validation Tests")
    class StartupValidationTests {

        @Test
        @DisplayName("Rejects null or secret shorter than 32 characters on startup")
        void shouldRejectShortSecret() {
            JwtService shortSecretService = new JwtService("too-short-key", 3600);
            assertThrows(IllegalStateException.class, shortSecretService::init);
        }

        @Test
        @DisplayName("Accepts secret with 32 or more characters")
        void shouldAcceptValidSecret() {
            JwtService validSecretService = new JwtService("12345678901234567890123456789012", 3600);
            assertDoesNotThrow(validSecretService::init);
        }
    }

    @Nested
    @DisplayName("Token Generation & Claim Tests")
    class TokenGenerationTests {

        @Test
        @DisplayName("Uses immutable user ID as subject, includes role, iat, exp claims")
        void shouldGenerateTokenWithRequiredClaims() {
            User user = new User(42L, "admin", "hash", UserRole.ADMIN);

            String token = jwtService.generateToken(user);
            assertNotNull(token);

            Claims claims = jwtService.parseAndValidateToken(token);
            assertEquals("42", claims.getSubject());
            assertEquals("ADMIN", claims.get("role", String.class));
            assertNotNull(claims.getIssuedAt());
            assertNotNull(claims.getExpiration());

            long diffSeconds = (claims.getExpiration().getTime() - claims.getIssuedAt().getTime()) / 1000;
            assertEquals(EXPIRATION_SECONDS, diffSeconds);
        }

        @Test
        @DisplayName("Accurately extracts user ID from valid token")
        void shouldExtractUserId() {
            User user = new User(100L, "testadmin", "hash", UserRole.ADMIN);
            String token = jwtService.generateToken(user);

            Long extractedId = jwtService.extractUserId(token);
            assertEquals(100L, extractedId);
        }
    }

    @Nested
    @DisplayName("Token Validation & Rejection Tests")
    class TokenValidationTests {

        @Test
        @DisplayName("Rejects malformed tokens")
        void shouldRejectMalformedToken() {
            assertThrows(MalformedJwtException.class, () -> jwtService.parseAndValidateToken("not.a.valid.jwt.token"));
            assertThrows(MalformedJwtException.class, () -> jwtService.parseAndValidateToken(""));
            assertThrows(MalformedJwtException.class, () -> jwtService.parseAndValidateToken(null));
        }

        @Test
        @DisplayName("Rejects expired tokens")
        void shouldRejectExpiredToken() {
            SecretKey key = Keys.hmacShaKeyFor(TEST_SECRET.getBytes(StandardCharsets.UTF_8));
            Date past = new Date(System.currentTimeMillis() - 10000);
            Date olderPast = new Date(past.getTime() - 10000);

            String expiredToken = Jwts.builder()
                    .subject("1")
                    .claim("role", "ADMIN")
                    .issuedAt(olderPast)
                    .expiration(past)
                    .signWith(key, Jwts.SIG.HS256)
                    .compact();

            assertThrows(ExpiredJwtException.class, () -> jwtService.parseAndValidateToken(expiredToken));
        }

        @Test
        @DisplayName("Rejects tokens with invalid signature")
        void shouldRejectInvalidSignature() {
            String wrongSecret = "completely-different-signing-secret-with-at-least-32-chars";
            SecretKey wrongKey = Keys.hmacShaKeyFor(wrongSecret.getBytes(StandardCharsets.UTF_8));

            String forgedToken = Jwts.builder()
                    .subject("1")
                    .claim("role", "ADMIN")
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(wrongKey, Jwts.SIG.HS256)
                    .compact();

            assertThrows(SignatureException.class, () -> jwtService.parseAndValidateToken(forgedToken));
        }

        @Test
        @DisplayName("Rejects tokens missing required claims")
        void shouldRejectTokenMissingRequiredClaims() {
            SecretKey key = Keys.hmacShaKeyFor(TEST_SECRET.getBytes(StandardCharsets.UTF_8));

            // Missing role claim
            String missingRole = Jwts.builder()
                    .subject("1")
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(key, Jwts.SIG.HS256)
                    .compact();

            assertThrows(JwtException.class, () -> jwtService.parseAndValidateToken(missingRole));

            // Missing subject claim
            String missingSub = Jwts.builder()
                    .claim("role", "ADMIN")
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(key, Jwts.SIG.HS256)
                    .compact();

            assertThrows(JwtException.class, () -> jwtService.parseAndValidateToken(missingSub));
        }

        @Test
        @DisplayName("Rejects tokens with invalid subject (non-numeric)")
        void shouldRejectNonNumericSubject() {
            SecretKey key = Keys.hmacShaKeyFor(TEST_SECRET.getBytes(StandardCharsets.UTF_8));

            String invalidSub = Jwts.builder()
                    .subject("not-a-number")
                    .claim("role", "ADMIN")
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(key, Jwts.SIG.HS256)
                    .compact();

            assertThrows(JwtException.class, () -> jwtService.parseAndValidateToken(invalidSub));
        }

        @Test
        @DisplayName("Rejects tokens with invalid role claim")
        void shouldRejectInvalidRoleClaim() {
            SecretKey key = Keys.hmacShaKeyFor(TEST_SECRET.getBytes(StandardCharsets.UTF_8));

            String invalidRole = Jwts.builder()
                    .subject("1")
                    .claim("role", "SUPER_GOD_ROLE")
                    .issuedAt(new Date())
                    .expiration(new Date(System.currentTimeMillis() + 3600000))
                    .signWith(key, Jwts.SIG.HS256)
                    .compact();

            assertThrows(JwtException.class, () -> jwtService.parseAndValidateToken(invalidRole));
        }
    }
}
