package com.mobili.backend.module.admin.repository;

import java.time.LocalDate;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.mobili.backend.module.admin.entity.LoginEvent;

public interface LoginEventRepository extends JpaRepository<LoginEvent, Long> {

    long countByLoginDate(LocalDate date);

    @Query("SELECT COUNT(DISTINCT e.userId) FROM LoginEvent e WHERE e.loginDate = :date")
    long countDistinctUsersByDate(@Param("date") LocalDate date);

    @Query("SELECT e.loginDate, COUNT(e), COUNT(DISTINCT e.userId) " +
           "FROM LoginEvent e " +
           "WHERE e.loginDate BETWEEN :from AND :to " +
           "GROUP BY e.loginDate " +
           "ORDER BY e.loginDate DESC")
    List<Object[]> dailyStatsBetween(@Param("from") LocalDate from, @Param("to") LocalDate to);
}
