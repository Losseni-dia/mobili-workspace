package com.mobili.backend.api.passenger.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.configuration.MobiliSecurityRefreshSettings;
import com.mobili.backend.infrastructure.security.auth.RefreshTokenCookieWriter;
import com.mobili.backend.infrastructure.security.token.JwtService;
import com.mobili.backend.module.admin.entity.LoginEvent;
import com.mobili.backend.module.admin.repository.LoginEventRepository;
import com.mobili.backend.module.analytics.service.AnalyticsEventService;
import com.mobili.backend.module.user.dto.RegisterCompanyPublicDTO;
import com.mobili.backend.module.user.dto.login.AuthResponse;
import com.mobili.backend.module.user.dto.login.LoginRequest;
import com.mobili.backend.module.user.dto.mapper.UserMapper;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import jakarta.servlet.http.HttpServletResponse;

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
    @Mock
    private RefreshTokenCookieWriter refreshTokenCookieWriter;
    @Mock
    private MobiliSecurityRefreshSettings refreshSettings;
    @Mock
    private HttpServletResponse httpServletResponse;

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
                analyticsEventService,
                refreshTokenCookieWriter,
                refreshSettings);
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

        MobiliException exception = assertThrows(MobiliException.class,
                () -> authController.login(request, httpServletResponse));
        assertEquals(MobiliErrorCode.ACCESS_DENIED, exception.getErrorCode());
    }

    @Test
    void registerCompanyReturnsJwtRefreshCookieAndLoginEvent() {
        RegisterCompanyPublicDTO dto = sampleRegisterCompanyDto();
        User saved = new User();
        saved.setId(42L);
        saved.setLogin("dirigeant01");

        when(userService.registerCompanyPublic(eq(dto), isNull())).thenReturn(saved);
        when(jwtService.generateToken(saved)).thenReturn("jwt-access-token");

        AuthResponse response = authController.registerCompany(dto, null, httpServletResponse);

        assertEquals("jwt-access-token", response.getToken());
        assertEquals("dirigeant01", response.getLogin());
        assertEquals(42L, response.getUserId());
        assertEquals(Boolean.FALSE, response.getAccountPending());

        verify(jwtService).generateToken(saved);
        verify(refreshTokenCookieWriter).write(httpServletResponse, saved);
        verify(loginEventRepository).save(argThat(
                (LoginEvent e) -> Long.valueOf(42L).equals(e.getUserId()) && "dirigeant01".equals(e.getLogin())));
    }

    @Test
    void registerCompanyPassesLogoToUserService() {
        RegisterCompanyPublicDTO dto = sampleRegisterCompanyDto();
        User saved = new User();
        saved.setId(7L);
        saved.setLogin("boss");
        MultipartFile logo = org.mockito.Mockito.mock(MultipartFile.class);

        when(userService.registerCompanyPublic(dto, logo)).thenReturn(saved);
        when(jwtService.generateToken(saved)).thenReturn("t");

        authController.registerCompany(dto, logo, httpServletResponse);

        verify(userService).registerCompanyPublic(dto, logo);
    }

    @Test
    void registerCompanyPropagatesMobiliExceptionAndSkipsJwtAndCookie() {
        RegisterCompanyPublicDTO dto = sampleRegisterCompanyDto();
        when(userService.registerCompanyPublic(any(RegisterCompanyPublicDTO.class), isNull()))
                .thenThrow(new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé."));

        MobiliException ex = assertThrows(MobiliException.class,
                () -> authController.registerCompany(dto, null, httpServletResponse));

        assertEquals(MobiliErrorCode.DUPLICATE_RESOURCE, ex.getErrorCode());
        verify(jwtService, never()).generateToken(any());
        verify(refreshTokenCookieWriter, never()).write(any(), any());
        verify(loginEventRepository, never()).save(any());
    }

    private static RegisterCompanyPublicDTO sampleRegisterCompanyDto() {
        RegisterCompanyPublicDTO dto = new RegisterCompanyPublicDTO();
        dto.setFirstname("Ada");
        dto.setLastname("Lovelace");
        dto.setLogin("dirigeant01");
        dto.setEmail("ada@example.com");
        dto.setPassword("secret12");
        dto.setCompanyName("Mobili Transport SAS");
        dto.setCompanyEmail("contact@mobili.ci");
        dto.setCompanyPhone("+22507080910");
        return dto;
    }
}
