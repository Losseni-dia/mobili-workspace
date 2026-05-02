package com.mobili.backend.module.partnergarecom.entity;

import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.shared.abstractEntity.AbstractEntity;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "partner_gare_com_thread_targets", uniqueConstraints = {
        @UniqueConstraint(columnNames = { "thread_id", "station_id" })
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class PartnerGareComThreadTarget extends AbstractEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "thread_id", nullable = false)
    private PartnerGareComThread thread;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "station_id", nullable = false)
    private Station station;
}
