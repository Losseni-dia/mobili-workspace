package com.mobili.backend.module.station.dto;

public record GareUserListItem(
                Long id,
                String firstname,
                String lastname,
                String email,
                String phone,
                String login,
                boolean enabled,
                Long stationId,
                String stationName) {
}