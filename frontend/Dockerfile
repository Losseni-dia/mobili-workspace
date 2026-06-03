# 1. Image de base : on utilise une version légère de Node.js sur Linux Alpine
FROM node:20-alpine

# 2. Dossier de travail : on crée et on se place dans /app à l'intérieur du container
WORKDIR /app

# 3. Optimisation du cache : on copie uniquement les fichiers de dépendances en premier
# Cela évite de tout réinstaller si tu modifies seulement ton code source (.ts, .html)
COPY package.json package-lock.json ./

# 4. Installation propre : 'npm ci' est plus rapide et plus strict que 'npm install' pour Docker
RUN npm ci

# 5. Copie du code : on transfère tout le reste de ton projet (src, assets, etc.)
COPY . .

# 6. Documentation : on indique que l'application écoute sur le port 4200
EXPOSE 4200

# 7. Lancement "Flexible"
# L'ENTRYPOINT est le "cœur" du container. On lui dit de lancer npm start.
ENTRYPOINT ["npm", "run", "start", "--"]

# Le CMD fournit les arguments par défaut. 
# Si tu lances le container normalement, il utilisera --host 0.0.0.0
CMD ["--host", "0.0.0.0"]