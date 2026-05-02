import { CONFIGURATION_DATA } from 'mobili-shared';

export function resolveMobiliEnvName(): keyof typeof CONFIGURATION_DATA.variables {
  const locHost = window.location.host;
  const locHostname = window.location.hostname;
  const envMatch = CONFIGURATION_DATA.environments.find((e) =>
    e.domain.some((d) => (d.includes(':') ? d === locHost : d === locHostname || d === locHost)),
  );
  return (envMatch ? envMatch.env : 'local') as keyof typeof CONFIGURATION_DATA.variables;
}
