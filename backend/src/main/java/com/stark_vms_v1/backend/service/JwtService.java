package com.stark_vms_v1.backend.service;

import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.entity.UserRole;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * Service for JWT creation, parsing, and validation.
 *
 * PRODUCTION DEPLOYMENT NOTE:
 * In production environments, app.jwt.secret MUST be supplied via external configuration,
 * such as the JWT_SECRET environment variable, with a cryptographically secure random secret
 * of at least 32 characters (256 bits).
 */
@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);

    private final String secret;
    private final long expirationSeconds;
    private SecretKey signingKey;

    public JwtService(
            @Value("${app.jwt.secret}") String secret,
            @Value("${app.jwt.expiration-seconds:3600}") long expirationSeconds
    ) {
        this.secret = secret;
        this.expirationSeconds = expirationSeconds;
    }

    @PostConstruct
    public void init() {
        validateSecret(secret);
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        log.info("JwtService initialized with HS256 algorithm and expiration lifetime of {} seconds.", expirationSeconds);
    }

    private void validateSecret(String secret) {
        if (secret == null || secret.trim().length() < 32) {
            throw new IllegalStateException("JWT signing secret (app.jwt.secret) must be at least 32 characters long. Provided secret length: " + (secret == null ? 0 : secret.length()));
        }
    }

    /**
     * Generates a signed HS256 JWT for the given user.
     * The subject contains the immutable user ID.
     */
    public String generateToken(User user) {
        if (user == null || user.getId() == null) {
            throw new IllegalArgumentException("User and user ID must not be null when generating token");
        }

        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + (expirationSeconds * 1000));

        return Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim("role", user.getRole().name())
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(signingKey, Jwts.SIG.HS256)
                .compact();
    }

    public long getExpirationSeconds() {
        return expirationSeconds;
    }

    /**
     * Parses and validates the JWT token.
     * Validates signature, expiration, algorithm, and all required claims.
     */
    public Claims parseAndValidateToken(String token) {
        if (token == null || token.isBlank()) {
            throw new MalformedJwtException("JWT token is null or blank");
        }

        Jws<Claims> jws = Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token);

        // Enforce expected algorithm HS256
        String alg = jws.getHeader().getAlgorithm();
        if (!"HS256".equals(alg)) {
            throw new JwtException("Unexpected JWT signing algorithm: " + alg);
        }

        Claims claims = jws.getPayload();

        // Enforce required claims presence
        String subject = claims.getSubject();
        String role = claims.get("role", String.class);
        Date issuedAt = claims.getIssuedAt();
        Date expiration = claims.getExpiration();

        if (subject == null || subject.isBlank()) {
            throw new JwtException("JWT is missing required claim: sub");
        }
        if (role == null || role.isBlank()) {
            throw new JwtException("JWT is missing required claim: role");
        }
        if (issuedAt == null) {
            throw new JwtException("JWT is missing required claim: iat");
        }
        if (expiration == null) {
            throw new JwtException("JWT is missing required claim: exp");
        }

        // Validate subject is a valid Long user ID
        try {
            Long.parseLong(subject);
        } catch (NumberFormatException e) {
            throw new JwtException("Invalid subject claim, expected numeric user ID: " + subject);
        }

        // Validate role matches an existing UserRole
        try {
            UserRole.valueOf(role);
        } catch (IllegalArgumentException e) {
            throw new JwtException("Invalid role claim: " + role);
        }

        return claims;
    }

    /**
     * Extracts user ID from token sub claim after full validation.
     */
    public Long extractUserId(String token) {
        Claims claims = parseAndValidateToken(token);
        return Long.parseLong(claims.getSubject());
    }
}
