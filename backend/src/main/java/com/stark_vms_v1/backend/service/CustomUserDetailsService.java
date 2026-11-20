package com.stark_vms_v1.backend.service;

import com.stark_vms_v1.backend.config.UserPrincipal;
import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.repository.UserRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    public CustomUserDetailsService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        String normalized = User.normalizeUsername(username);
        User user = userRepository.findByUsername(normalized)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with username: " + normalized));
        return UserPrincipal.fromUser(user);
    }
}
