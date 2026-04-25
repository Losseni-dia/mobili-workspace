import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { App } from '../src/app/app';
 // Vérifie que le fichier est bien src/app/app.ts

bootstrapApplication(App, appConfig).catch((err) => console.error(err));
