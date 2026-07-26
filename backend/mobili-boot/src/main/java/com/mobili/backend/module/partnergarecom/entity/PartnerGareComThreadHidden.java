package com.mobili.backend.module.partnergarecom.entity;

import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "partner_gare_com_thread_hidden")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class PartnerGareComThreadHidden extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "thread_id", nullable = false)
    private PartnerGareComThread thread;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "station_id")
    private Station station;

    @Column(name = "hidden_at", nullable = false)
    private LocalDateTime hiddenAt;
}