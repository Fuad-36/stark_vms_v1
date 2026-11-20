package com.stark_vms_v1.backend.config;

import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.repository.UserRepository;
import com.stark_vms_v1.backend.service.JwtService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final CustomAuthenticationEntryPoint authenticationEntryPoint;

    public JwtAuthenticationFilter(
            JwtService jwtService,
            UserRepository userRepository,
            CustomAuthenticationEntryPoint authenticationEntryPoint
    ) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.authenticationEntryPoint = authenticationEntryPoint;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return "OPTIONS".equalsIgnoreCase(request.getMethod());
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);

        // If no Authorization header is present, continue to Spring Security filter chain.
        // Protected endpoints will be caught by Spring Security and invoke CustomAuthenticationEntryPoint.
        if (authHeader == null) {
            filterChain.doFilter(request, response);
            return;
        }

        // Invalid Bearer scheme
        if (!authHeader.startsWith("Bearer ")) {
            authenticationEntryPoint.commence(
                    request,
                    response,
                    new BadCredentialsException("Authorization header must use Bearer scheme")
            );
            return;
        }

        String token = authHeader.substring(7).trim();
        if (token.isEmpty()) {
            authenticationEntryPoint.commence(
                    request,
                    response,
                    new BadCredentialsException("Bearer token must not be empty")
            );
            return;
        }

        try {
            Long userId = jwtService.extractUserId(token);

            // Always check database for user existence on every authenticated request
            User user = userRepository.findById(userId).orElse(null);
            if (user == null) {
                SecurityContextHolder.clearContext();
                authenticationEntryPoint.commence(
                        request,
                        response,
                        new BadCredentialsException("User does not exist or has been deleted")
                );
                return;
            }

            // Obtain current role from database, not trusting outdated role claim
            SimpleGrantedAuthority authority = new SimpleGrantedAuthority("ROLE_" + user.getRole().name());
            UserPrincipal principal = UserPrincipal.fromUser(user);

            UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                    principal,
                    null,
                    Collections.singletonList(authority)
            );
            authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(authentication);

        } catch (Exception ex) {
            SecurityContextHolder.clearContext();
            authenticationEntryPoint.commence(
                    request,
                    response,
                    new BadCredentialsException("Invalid, expired, or malformed JWT token", ex)
            );
            return;
        }

        filterChain.doFilter(request, response);
    }
}
