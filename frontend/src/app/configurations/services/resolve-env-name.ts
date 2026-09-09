import { CONFIGURATION_DATA } from 'mobili-shared';

export function resolveMobiliEnvName(): keyof typeof CONFIGURATION_DATA.variables {
  // Rendu côté serveur (SSR) : pas de `window` — mais ce process Node ne sert jamais que le
  // build déployé (staging/prod), jamais `ng serve` (dev local, toujours en CSR pur), donc
  // 'prod' est un repli sûr et non un cas ambigu à deviner.
  if (typeof window === 'undefined') {
    return 'prod';
  }
  const locHost = window.location.host;
  const locHostname = window.location.hostname;
  const envMatch = CONFIGURATION_DATA.environments.find((e) =>
    e.domain.some((d) => (d.includes(':') ? d === locHost : d === locHostname || d === locHost)),
  );
  return (envMatch ? envMatch.env : 'local') as keyof typeof CONFIGURATION_DATA.variables;
}
