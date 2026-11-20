package com.stark_vms_v1.backend.dto;

public class LoginResponse {

    private String token;
    private String tokenType;
    private long expiresIn;
    private String username;

    public LoginResponse() {
    }

    public LoginResponse(String token, String tokenType, long expiresIn, String username) {
        this.token = token;
        this.tokenType = tokenType;
        this.expiresIn = expiresIn;
        this.username = username;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public String getTokenType() {
        return tokenType;
    }

    public void setTokenType(String tokenType) {
        this.tokenType = tokenType;
    }

    public long getExpiresIn() {
        return expiresIn;
    }

    public void setExpiresIn(long expiresIn) {
        this.expiresIn = expiresIn;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }
}
