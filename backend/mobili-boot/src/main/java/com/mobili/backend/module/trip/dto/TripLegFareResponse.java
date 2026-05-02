package com.mobili.backend.module.trip.dto;

public record TripLegFareResponse(int fromStopIndex, int toStopIndex, double price) {
}
