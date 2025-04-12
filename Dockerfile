# Étape 1: Choisir l'image de base Python
FROM python:3.12-slim

# --- AJOUT : Arguments pour l'utilisateur ---
# Définit des arguments pour l'UID, le GID et le nom d'utilisateur.
# Ces valeurs peuvent être surchargées lors du build (ex: via devcontainer.json)
# 1000 est un UID/GID courant sur Linux. Adaptez si nécessaire pour votre système hôte.
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=vscode

# Étape 2: Définir le répertoire de travail (sera créé par root initialement)
WORKDIR /app

# Étape 3: Installer les dépendances système + sudo
# Ajout de 'sudo' pour permettre à l'utilisateur non-root d'installer des paquets plus tard si besoin
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    sudo \
 && rm -rf /var/lib/apt/lists/*

# --- AJOUT : Création du groupe et de l'utilisateur (version GID-safe) ---
# Vérifie d'abord si un groupe avec le GID cible existe.
# Si NON, crée le groupe avec le nom d'utilisateur désiré.
# Si OUI, affiche un message et continue (utilisera le groupe existant).
# Ensuite, crée l'utilisateur avec l'UID et le GID spécifiés.
RUN if ! getent group $USER_GID > /dev/null; then \
        echo "Creating group $USERNAME with GID $USER_GID"; \
        groupadd --gid $USER_GID $USERNAME; \
    else \
        echo "Group with GID $USER_GID already exists. Assigning user $USERNAME to it."; \
    fi \
 && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
 # Ajoute l'utilisateur au groupe sudoers sans mot de passe requis
 && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
 && chmod 0440 /etc/sudoers.d/$USERNAME

# Étape 4: Copier uniquement le fichier des dépendances
# Copié avant de changer d'utilisateur pour potentiellement utiliser le cache Docker
COPY requirements.txt .

# Étape 5: Installer les dépendances Python
# Fait en tant que root pour installer globalement dans l'environnement virtuel de base
RUN pip install --no-cache-dir -r requirements.txt

# --- AJOUT : Changer le propriétaire du WORKDIR avant de copier le reste ---
# Donne la propriété du dossier /app (et de requirements.txt dedans) à l'utilisateur créé
# Utilise les numéros UID/GID directement car le nom du groupe pourrait ne pas correspondre à $USERNAME
# Note: Cette commande s'exécute toujours en tant que root car elle vient avant 'USER $USERNAME'
RUN chown -R $USER_UID:$USER_GID /app

# --- AJOUT : Passer à l'utilisateur non-root ---
# Les commandes suivantes (COPY, CMD) s'exécuteront en tant que $USERNAME
USER $USERNAME

# Étape 6: Copier tout le reste du projet (notebooks, etc.)
# S'exécute maintenant en tant que $USERNAME, les fichiers copiés appartiendront à $USERNAME
# Assurez-vous d'avoir un fichier .dockerignore pour exclure les éléments non nécessaires (ex: .git, .vscode-server)
COPY . .

# Étape 7: Exposer le port sur lequel Jupyter va écouter
EXPOSE 8888

# Étape 8: Commande à exécuter au démarrage du container
# Lance Jupyter Lab en tant qu'utilisateur non-root ($USERNAME)
# Plus besoin de --allow-root
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser"]