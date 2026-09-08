package com.mobili.backend.module.routing.mapbox.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.exception.NoRouteFoundException;

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

/**
 * MockRestServiceServer lié au RestClient.Builder — pattern Spring standard pour tester du code
 * RestClient sans mocker manuellement toute la chaîne fluide (RequestHeadersUriSpec /
 * RequestHeadersSpec / ResponseSpec), qui serait fragile au moindre changement d'appel.
 */
class MapboxDirectionsServiceTest {

    private final RestClient.Builder builder = RestClient.builder();
    private final MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
    private final MapboxDirectionsService service = new MapboxDirectionsService(builder);

    private void withAccessToken() {
        ReflectionTestUtils.setField(service, "accessToken", "test-token");
    }

    @Test
    void getDirections_okResponse_returnsMapboxResult() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andExpect(requestTo(org.hamcrest.Matchers.containsString("access_token=test-token")))
                .andRespond(withSuccess(
                        "{\"code\":\"Ok\",\"routes\":[{\"duration\":905.4,\"distance\":12345.6}]}",
                        MediaType.APPLICATION_JSON));

        DirectionsResult result = service.getDirections(
                new DirectionsRequest(5.35, -4.02, 5.36, -4.03));

        assertEquals(905L, result.durationSeconds());
        assertEquals(12345.6, result.distanceMeters());
        assertEquals(DirectionsProvider.MAPBOX, result.provider());
        server.verify();
    }

    @Test
    void getDirections_noRouteCode_throwsNoRouteFoundException() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andRespond(withSuccess("{\"code\":\"NoRoute\"}", MediaType.APPLICATION_JSON));

        assertThrows(NoRouteFoundException.class,
                () -> service.getDirections(new DirectionsRequest(5.35, -4.02, 5.36, -4.03)));
        server.verify();
    }

    @Test
    void getDirections_okCodeButEmptyRoutes_throwsNoRouteFoundException() {
        withAccessToken();
        server.expect(method(org.springframework.http.HttpMethod.GET))
                .andRespond(withSuccess("{\"code\":\"Ok\",\"routes\":[]}", MediaType.APPLICATION_JSON));

        assertThrows(NoRouteFoundException.class,
                () -> service.getDirections(new DirectionsRequest(5.35, -4.02, 5.36, -4.03)));
        server.verify();
    }

    @Test
    void getDirectionsProvider_returnsMapbox() {
        assertEquals(DirectionsProvider.MAPBOX, service.getDirectionsProvider());
    }
}
