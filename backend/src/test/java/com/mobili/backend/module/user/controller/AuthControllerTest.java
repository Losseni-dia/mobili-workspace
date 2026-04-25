package com.mobili.backend.module.user.controller;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.mobili.backend.infrastructure.security.token.JwtService;
import com.mobili.backend.module.admin.repository.LoginEventRepository;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.user.dto.login.LoginRequest;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

@ExtendWith(MockitoExtension.class)
class AuthControllerTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private JwtService jwtService;
    @Mock
    private UserMapper userMapper;
    @Mock
    private UserService userService;
    @Mock
    private LoginEventRepository loginEventRepository;
    @Mock
    private AnalyticsEventService analyticsEventService;

    private AuthController authController;

    @BeforeEach
    void setUp() {
        authController = new AuthController(
                userRepository,
                passwordEncoder,
                jwtService,
                userMapper,
                userService,
                loginEventRepository,
                analyticsEventService);
    }

    @Test
    void loginRejectsDisabledAccount() {
        LoginRequest request = new LoginRequest();
        request.setLogin("john");
        request.setPassword("secret");

        User user = new User();
        user.setLogin("john");
        user.setPassword("hashed");
        user.setEnabled(false);

        when(userRepository.findByLogin("john")).thenReturn(Optional.of(user));

        MobiliException exception = assertThrows(MobiliException.class, () -> authController.login(request));
        assertEquals(MobiliErrorCode.ACCESS_DENIED, exception.getErrorCode());
    }
}
