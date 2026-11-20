package com.stark_vms_v1.backend.config;

import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.entity.UserRole;
import com.stark_vms_v1.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Seeds a default administrator user if the entire user table is empty.
 *
 * DEVELOPMENT CREDENTIALS NOTICE / PRODUCTION SECURITY RISK:
 * The seeded credentials (username: "admin", password: "Admin@123") are strictly intended
 * for DEVELOPMENT USE ONLY.
 *
 * IMPORTANT RISK DOCUMENTATION:
 * This seeder runs whenever the user table is completely empty, regardless of active Spring profile.
 * Consequently, deploying to an empty production database will create this predictable administrator
 * account if initial administrative credentials are not provisioned beforehand.
 * In production environments, initial administrative access must be secured by changing this
 * default password immediately upon deployment or provisioning users via a secure deployment pipeline.
 */
@Component
public class AdminUserSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminUserSeeder.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AdminUserSeeder(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        if (userRepository.count() == 0) {
            log.info("User table is empty. Seeding development administrator account.");
            User admin = new User();
            admin.setUsername("admin");
            // Store password strictly as BCrypt hash; never log or persist plaintext
            admin.setPassword(passwordEncoder.encode("Admin@123"));
            admin.setRole(UserRole.ADMIN);
            userRepository.save(admin);
            log.info("Development administrator account successfully seeded.");
        } else {
            log.info("User table is not empty. Skipping admin account seeding.");
        }
    }
}
