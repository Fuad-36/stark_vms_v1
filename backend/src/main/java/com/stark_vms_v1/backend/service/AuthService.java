package com.stark_vms_v1.backend.service;

import com.stark_vms_v1.backend.dto.LoginRequest;
import com.stark_vms_v1.backend.dto.LoginResponse;
import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.repository.UserRepository;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.stereotype.Service;

@Service
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final JwtService jwtService;

    public AuthService(
            AuthenticationManager authenticationManager,
            UserRepository userRepository,
            JwtService jwtService
    ) {
        this.authenticationManager = authenticationManager;
        this.userRepository = userRepository;
        this.jwtService = jwtService;
    }

    public LoginResponse login(LoginRequest request) {
        String normalizedUsername = User.normalizeUsername(request.getUsername());

        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(normalizedUsername, request.getPassword())
            );
        } catch (AuthenticationException ex) {
            // Return same generic error message whether user does not exist or password is wrong
            throw new BadCredentialsException("Invalid username or password");
        }

        User user = userRepository.findByUsername(normalizedUsername)
                .orElseThrow(() -> new BadCredentialsException("Invalid username or password"));

        String token = jwtService.generateToken(user);

        return new LoginResponse(
                token,
                "Bearer",
                jwtService.getExpirationSeconds(),
                user.getUsername()
        );
    }
}
