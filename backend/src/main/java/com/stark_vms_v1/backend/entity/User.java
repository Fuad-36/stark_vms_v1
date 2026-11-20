package com.stark_vms_v1.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.Locale;
import java.util.Objects;

@Entity
@Table(
        name = "users",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_users_username", columnNames = {"username"})
        }
)
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank(message = "Username is required")
    @Size(max = 50, message = "Username must not exceed 50 characters")
    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @NotBlank(message = "Password is required")
    @Column(nullable = false)
    private String password;

    @NotNull(message = "Role is required")
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UserRole role = UserRole.ADMIN;

    public User() {
    }

    public User(String username, String password, UserRole role) {
        this.username = normalizeUsername(username);
        this.password = password;
        this.role = role != null ? role : UserRole.ADMIN;
    }

    public User(Long id, String username, String password, UserRole role) {
        this.id = id;
        this.username = normalizeUsername(username);
        this.password = password;
        this.role = role != null ? role : UserRole.ADMIN;
    }

    @PrePersist
    protected void onPrePersist() {
        this.username = normalizeUsername(this.username);
        if (this.role == null) {
            this.role = UserRole.ADMIN;
        }
    }

    @PreUpdate
    protected void onPreUpdate() {
        this.username = normalizeUsername(this.username);
        if (this.role == null) {
            this.role = UserRole.ADMIN;
        }
    }

    public static String normalizeUsername(String username) {
        if (username == null) {
            return null;
        }
        return username.trim().toLowerCase(Locale.ROOT);
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = normalizeUsername(username);
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public UserRole getRole() {
        return role;
    }

    public void setRole(UserRole role) {
        this.role = role != null ? role : UserRole.ADMIN;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        User user = (User) o;
        return Objects.equals(id, user.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }

    @Override
    public String toString() {
        return "User{" +
                "id=" + id +
                ", username='" + username + '\'' +
                ", role=" + role +
                '}';
    }
}
