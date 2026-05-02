package com.mobili.backend.api.passenger.media;

import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.shared.sharedService.PrivateMediaService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/v1/media")
@RequiredArgsConstructor
public class PrivateMediaController {

    private final PrivateMediaService privateMediaService;

    /**
     * Médias sensibles (KYC covoiturage, etc.) : JWT obligatoire, jamais servis sous {@code /uploads/**} public.
     */
    @GetMapping("/private")
    public ResponseEntity<Resource> getPrivate(
            @RequestParam("rel") String rel,
            @AuthenticationPrincipal UserPrincipal principal) {
        var path = privateMediaService.requireReadableFile(principal, rel);
        Resource body = new FileSystemResource(path);
        String ct = PrivateMediaService.probeContentType(path);
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .header(HttpHeaders.CONTENT_TYPE, ct)
                .body(body);
    }
}
