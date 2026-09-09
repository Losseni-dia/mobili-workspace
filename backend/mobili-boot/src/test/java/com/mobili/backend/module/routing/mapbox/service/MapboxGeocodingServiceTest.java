package com.mobili.backend.module.routing.mapbox.service;

import com.mobili.backend.module.routing.exception.GeocodingFailedException;
import com.mobili.backend.module.routing.mapbox.dto.GeocodingResult;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class MapboxGeocodingServiceTest {

    private final RestClient.Builder builder = RestClient.builder();
    private final MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
    private final MapboxGeocodingService service = new MapboxGeocodingService(builder);

    private void withAccessToken() {
        ReflectionTestUtils.setField(service, "accessToken", "test-token");
    }

    @Test
    void geocode_validFeature_returnsLatLng() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andExpect(requestTo(org.hamcrest.Matchers.containsString("access_token=test-token")))
                .andExpect(requestTo(org.hamcrest.Matchers.containsString("proximity=-4.0083,5.3600")))
                .andRespond(withSuccess(
                        "{\"features\":[{\"center\":[-5.0167,6.5500]}]}",
                        MediaType.APPLICATION_JSON));

        GeocodingResult result = service.geocode("Toumodi");

        assertEquals(6.5500, result.latitude());
        assertEquals(-5.0167, result.longitude());
        server.verify();
    }

    @Test
    void geocode_withCountryCode_addsCountryQueryParam() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andExpect(requestTo(org.hamcrest.Matchers.containsString("country=ci")))
                .andRespond(withSuccess(
                        "{\"features\":[{\"center\":[-7.6833,8.2833]}]}",
                        MediaType.APPLICATION_JSON));

        GeocodingResult result = service.geocode("Touba", "CI");

        assertEquals(8.2833, result.latitude());
        assertEquals(-7.6833, result.longitude());
        server.verify();
    }

    @Test
    void geocode_nullCountryCode_omitsCountryQueryParam() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andExpect(requestTo(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("country="))))
                .andRespond(withSuccess(
                        "{\"features\":[{\"center\":[-5.0167,6.5500]}]}",
                        MediaType.APPLICATION_JSON));

        service.geocode("Toumodi", null);

        server.verify();
    }

    @Test
    void geocode_emptyFeatures_throwsGeocodingFailedException() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andRespond(withSuccess("{\"features\":[]}", MediaType.APPLICATION_JSON));

        assertThrows(GeocodingFailedException.class, () -> service.geocode("Villeinconnue"));
        server.verify();
    }

    @Test
    void geocode_noFeaturesField_throwsGeocodingFailedException() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));

        assertThrows(GeocodingFailedException.class, () -> service.geocode("Villeinconnue"));
        server.verify();
    }
}
