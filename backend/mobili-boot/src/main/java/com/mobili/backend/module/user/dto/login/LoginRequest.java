package com.mobili.backend.module.user.dto.login;

import lombok.Data;

@Data
public class LoginRequest {
    private String login;
    private String password;
}