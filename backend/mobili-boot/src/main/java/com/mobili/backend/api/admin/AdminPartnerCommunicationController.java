package com.mobili.backend.api.admin;

import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.mobili.backend.module.admin.dto.AdminPartnerCommunicationRequest;
import com.mobili.backend.module.admin.dto.AdminPartnerCommunicationResponse;
import com.mobili.backend.module.admin.service.AdminPartnerCommunicationService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Annonces admin → inbox des comptes dirigeants (propriétaire partenaire). Dédié à ce flux pour
 * un mapping HTTP explicite (évite la confusion “ressource statique” sur GET accidentel).
 */
@RestController
@RequestMapping("/v1/admin")
@RequiredArgsConstructor
@Slf4j
public class AdminPartnerCommunicationController {

    private final AdminPartnerCommunicationService adminPartnerCommunicationService;

    /**
     * Réservé au POST JSON. Un GET ici (ex. test dans le navigateur) renvoyait auparavant une erreur
     * de type ressource statique ; on documente l’API à la place.
     */
    @GetMapping(value = "/partner-communications", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> partnerCommunicationsGetDoc() {
        return Map.of(
                "method", "POST",
                "contentType", MediaType.APPLICATION_JSON_VALUE,
                "summary", "Annonce : dirigeants (propriétaire de fiche partenaire) +, si segment ALL ou COVOITURAGE_POOL, chauffeurs covoiturage au KYC approuvé.",
                "body", Map.of(
                        "title", "string (requis, max 300)",
                        "body", "string (requis, max 2000)",
                        "target", "BROADCAST | PICK",
                        "segment", "ALL | COMPANIES | COVOITURAGE_POOL (si target=BROADCAST)",
                        "includeDisabled", "boolean (si BROADCAST)",
                        "partnerIds", "number[] (si PICK)"));
    }

    @PostMapping(
            value = "/partner-communications",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<AdminPartnerCommunicationResponse> send(
            @Valid @RequestBody AdminPartnerCommunicationRequest request) {
        log.info("POST /v1/admin/partner-communications — target={}, segment={}",
                request.getTarget(), request.getSegment());
        return ResponseEntity.ok(adminPartnerCommunicationService.send(request));
    }
}
