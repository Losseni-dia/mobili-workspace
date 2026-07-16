package com.mobili.backend.infrastructure.security.authentication;

import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;
    private final StationRepository stationRepository;

    @Override
    public UserDetails loadUserByUsername(String login) {
        var userOpt = userRepository.findByLogin(login);
        if (userOpt.isPresent()) {
            return UserPrincipal.fromUser(userOpt.get());
        }

        var stationOpt = stationRepository.findByCode(login);
        if (stationOpt.isPresent()) {
            return new StationPrincipal(stationOpt.get());
        }

        throw new MobiliException(
                MobiliErrorCode.INVALID_CREDENTIALS,
                "Utilisateur non trouvé avec le login : " + login);
    }
}