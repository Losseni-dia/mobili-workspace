package com.mobili.backend.infrastructure.security.authentication;



import com.mobili.backend.module.user.entity.User;

import lombok.Getter;

import org.springframework.security.core.GrantedAuthority;

import org.springframework.security.core.authority.SimpleGrantedAuthority;

import org.springframework.security.core.userdetails.UserDetails;



import java.util.Collection;

import java.util.Collections;

import java.util.stream.Collectors;



/**

 * Identité Spring Security. Les id partenaire / gare sont figés à la construction (chargement

 * {@link com.mobili.backend.module.user.repository.UserRepository#findByLogin}) pour ne plus

 * toucher des associations lazy hors session Hibernate (sinon

 * {@link org.hibernate.LazyInitializationException} sur {@code User#getStation()}).

 */

public class UserPrincipal implements UserDetails {



    @Getter

    private final User user;

    private final Long partnerId;

    private final Long stationId;



    public static UserPrincipal fromUser(User user) {

        Long stationId = null;

        if (user.getStation() != null) {

            stationId = user.getStation().getId();

        }

        Long partnerId = null;

        if (user.getStation() != null && user.getStation().getPartner() != null) {

            partnerId = user.getStation().getPartner().getId();

        } else if (user.getPartner() != null) {

            partnerId = user.getPartner().getId();

        } else if (user.getEmployerPartner() != null) {

            partnerId = user.getEmployerPartner().getId();

        }

        return new UserPrincipal(user, partnerId, stationId);

    }



    public UserPrincipal(User user, Long partnerId, Long stationId) {

        this.user = user;

        this.partnerId = partnerId;

        this.stationId = stationId;

    }



    public Long getPartnerId() {

        return partnerId;

    }



    public Long getStationId() {

        return stationId;

    }



    @Override

    public Collection<? extends GrantedAuthority> getAuthorities() {

        if (user.getRoles() == null) {

            return Collections.emptyList();

        }

        return user.getRoles().stream()

                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.getName().name()))

                .collect(Collectors.toList());

    }



    @Override

    public String getPassword() {

        return user.getPassword();

    }



    @Override

    public String getUsername() {

        return user.getLogin();

    }



    @Override

    public boolean isAccountNonExpired() {

        return true;

    }



    @Override

    public boolean isAccountNonLocked() {

        return true;

    }



    @Override

    public boolean isCredentialsNonExpired() {

        return true;

    }



    @Override

    public boolean isEnabled() {

        return user.isEnabled();

    }

}

