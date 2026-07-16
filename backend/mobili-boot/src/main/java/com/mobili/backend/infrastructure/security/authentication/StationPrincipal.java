package com.mobili.backend.infrastructure.security.authentication;

import com.mobili.backend.module.station.entity.Station;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/**
 * Identité Spring Security pour une connexion "gare" : le code unique de la
 * {@link Station}
 * sert d'identifiant, le mot de passe est propre à la gare (indépendant de tout
 * chef de gare).
 */
public class StationPrincipal implements UserDetails {

    @Getter
    private final Station station;

    public StationPrincipal(Station station) {
        this.station = station;
    }

    public Long getStationId() {
        return station.getId();
    }

    public Long getPartnerId() {
        return station.getPartner() != null ? station.getPartner().getId() : null;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_STATION"));
    }

    @Override
    public String getPassword() {
        return station.getPassword();
    }

    @Override
    public String getUsername() {
        return station.getCode();
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
        return station.isActive();
    }
}