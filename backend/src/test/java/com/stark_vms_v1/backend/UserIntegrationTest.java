package com.stark_vms_v1.backend;

import com.stark_vms_v1.backend.config.AdminUserSeeder;
import com.stark_vms_v1.backend.entity.User;
import com.stark_vms_v1.backend.entity.UserRole;
import com.stark_vms_v1.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@DisplayName("User JPA & Admin Seeder Integration Tests")
class UserIntegrationTest {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AdminUserSeeder adminUserSeeder;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Nested
    @DisplayName("User Entity & Normalization Tests")
    class UserEntityTests {

        @Test
        @DisplayName("Stores password as BCrypt hash, never plaintext")
        void shouldStorePasswordAsBCryptHash() {
            User user = new User();
            user.setUsername("testuser");
            String rawPassword = "TestPassword@123";
            user.setPassword(passwordEncoder.encode(rawPassword));
            user.setRole(UserRole.ADMIN);

            User saved = userRepository.save(user);

            User retrieved = userRepository.findById(saved.getId()).orElseThrow();
            assertNotEquals(rawPassword, retrieved.getPassword());
            assertTrue(passwordEncoder.matches(rawPassword, retrieved.getPassword()));
            assertTrue(retrieved.getPassword().startsWith("$2a$") || retrieved.getPassword().startsWith("$2b$"));
        }

        @Test
        @DisplayName("Normalizes username by trimming whitespace and converting to lowercase")
        void shouldNormalizeUsernameBeforePersistence() {
            User user = new User();
            user.setUsername("   SuperAdminUser   ");
            user.setPassword(passwordEncoder.encode("Secret@123"));
            user.setRole(UserRole.ADMIN);

            User saved = userRepository.save(user);

            User retrieved = userRepository.findById(saved.getId()).orElseThrow();
            assertEquals("superadminuser", retrieved.getUsername());
        }

        @Test
        @DisplayName("Enforces database uniqueness on username")
        void shouldEnforceDatabaseUniquenessOnUsername() {
            User u1 = new User("uniqueadmin", passwordEncoder.encode("Pass@123"), UserRole.ADMIN);
            userRepository.save(u1);

            User u2 = new User("   UNIQUEADMIN   ", passwordEncoder.encode("Pass@456"), UserRole.ADMIN);
            assertThrows(DataIntegrityViolationException.class, () -> {
                userRepository.saveAndFlush(u2);
            });
        }
    }

    @Nested
    @DisplayName("Admin Seeder Tests")
    class AdminSeederTests {

        @Test
        @DisplayName("Admin is created when entire user table is empty")
        void shouldSeedAdminWhenTableIsEmpty() {
            assertEquals(0, userRepository.count());

            adminUserSeeder.run();

            assertEquals(1, userRepository.count());
            Optional<User> adminOpt = userRepository.findByUsername("admin");
            assertTrue(adminOpt.isPresent());

            User admin = adminOpt.get();
            assertEquals("admin", admin.getUsername());
            assertEquals(UserRole.ADMIN, admin.getRole());
            assertTrue(passwordEncoder.matches("Admin@123", admin.getPassword()));
        }

        @Test
        @DisplayName("Admin is not created when at least one user already exists")
        void shouldNotSeedAdminWhenUsersExist() {
            User existing = new User("otheruser", passwordEncoder.encode("SomePass@123"), UserRole.ADMIN);
            userRepository.save(existing);
            assertEquals(1, userRepository.count());

            adminUserSeeder.run();

            assertEquals(1, userRepository.count());
            assertTrue(userRepository.findByUsername("otheruser").isPresent());
            assertFalse(userRepository.findByUsername("admin").isPresent());
        }

        @Test
        @DisplayName("Application restart does not create duplicate users")
        void shouldNotDuplicateUsersOnRestart() {
            // First run
            adminUserSeeder.run();
            assertEquals(1, userRepository.count());
            User initialAdmin = userRepository.findByUsername("admin").orElseThrow();

            // Simulate restart / second run
            adminUserSeeder.run();
            assertEquals(1, userRepository.count());
            User postRestartAdmin = userRepository.findByUsername("admin").orElseThrow();
            assertEquals(initialAdmin.getId(), postRestartAdmin.getId());
            assertEquals(initialAdmin.getPassword(), postRestartAdmin.getPassword());
        }
    }
}
