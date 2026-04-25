package com.mobili.backend.infrastructure.security.authentication;

import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    public UserDetails loadUserByUsername(String login) {
        User user = userRepository.findByLogin(login)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.INVALID_CREDENTIALS,
                        "Utilisateur non trouvé avec le login : " + login));

        return UserPrincipal.fromUser(user);
    }
}