package com.mobili.backend.module.routing.google.service;

import com.mobili.backend.module.routing.dto.DirectionsRequest;
import com.mobili.backend.module.routing.dto.DirectionsResult;
import com.mobili.backend.module.routing.enums.DirectionsProvider;
import com.mobili.backend.module.routing.exception.NoRouteFoundException;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

/** Même pattern que MapboxDirectionsServiceTest — MockRestServiceServer lié au RestClient.Builder. */
class GoogleMapsDirectionsServiceTest {

    private final RestClient.Builder builder = RestClient.builder();
    private final MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
    private final GoogleMapsDirectionsService service = new GoogleMapsDirectionsService(builder);

    private void withApiKey() {
        ReflectionTestUtils.setField(service, "apiKey", "test-key");
    }

    @Test
    void getDirections_okResponse_returnsGoogleMapsResult() {
        withApiKey();
        server.expect(method(HttpMethod.GET))
                .andRespond(withSuccess(
                        "{\"status\":\"OK\",\"routes\":[{\"legs\":[{"
                                + "\"duration\":{\"value\":720},\"distance\":{\"value\":9800}}]}]}",
                        MediaType.APPLICATION_JSON));

        DirectionsResult result = service.getDirections(
                new DirectionsRequest(5.35, -4.02, 5.36, -4.03));

        assertEquals(720L, result.durationSeconds());
        assertEquals(9800.0, result.distanceMeters());
        assertEquals(DirectionsProvider.GOOGLE_MAPS, result.provider());
        server.verify();
    }

    @Test
    void getDirections_zeroResults_throwsNoRouteFoundException() {
        withApiKey();
        server.expect(method(HttpMethod.GET))
                .andRespond(withSuccess("{\"status\":\"ZERO_RESULTS\"}", MediaType.APPLICATION_JSON));

        assertThrows(NoRouteFoundException.class,
                () -> service.getDirections(new DirectionsRequest(5.35, -4.02, 5.36, -4.03)));
        server.verify();
    }

    @Test
    void getDirections_invalidRequestStatus_throwsIllegalStateException() {
        withApiKey();
        server.expect(method(HttpMethod.GET))
                .andRespond(withSuccess("{\"status\":\"INVALID_REQUEST\"}", MediaType.APPLICATION_JSON));

        assertThrows(IllegalStateException.class,
                () -> service.getDirections(new DirectionsRequest(5.35, -4.02, 5.36, -4.03)));
        server.verify();
    }

    @Test
    void getDirectionsProvider_returnsGoogleMaps() {
        assertEquals(DirectionsProvider.GOOGLE_MAPS, service.getDirectionsProvider());
    }
}
