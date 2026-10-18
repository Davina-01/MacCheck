**Français** · [English](README.en.md) · [简体中文](README.zh-CN.md)

# MacCheck

> [!WARNING]
> **Version en cours de débogage : de nombreux bugs sont encore présents.** Cette version est toujours en phase de test et de correction. Certaines fonctions peuvent ne pas marcher ou faire planter l'application. Merci de signaler tout problème dans les [issues](../../issues).

> [!NOTE]
> **À propos de cette version.** Il s'agit d'une version modifiée (fork) du projet open source **[andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)** créé par andyhuo520. Elle a été adaptée avec l'aide de l'IA pour proposer une **interface en trois langues (English / Français / 简体中文)** et **la prise en charge de nombreuses dispositions de clavier nationales**, ainsi que des corrections pour plusieurs problèmes signalés sur le projet d'origine. Ces modifications ayant été réalisées avec l'aide de l'IA et n'ayant pas encore été testées sur tous les modèles de Mac, **cette version peut contenir des bugs ou des erreurs. Vos retours sont les bienvenus** : [ouvrez une issue](../../issues) en indiquant votre modèle de Mac, votre version de macOS et ce que vous avez constaté.
>
> Ce fork est maintenu par **[innomicro.fr](https://innomicro.fr)**.
>
> Liens open source :
> - Projet d'origine : [github.com/andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)
> - Cette version modifiée : [github.com/Davina-01/MacCheck](https://github.com/Davina-01/MacCheck)
>
> Les résultats sont indicatifs et ne constituent pas une garantie : voir l'**Avertissement et limitation de responsabilité** en bas de page.
>
> Merci à andyhuo520 d'avoir publié le projet d'origine en open source. Le dépôt d'origine ne contient pas de fichier de licence ; si vous souhaitez redistribuer cette application à des fins commerciales, contactez d'abord l'auteur d'origine.

MacCheck est un outil macOS local pour contrôler un Mac d'occasion, à l'achat, à la vente, en boutique ou en autodiagnostic. Il lit automatiquement les caractéristiques matérielles, la batterie, le stockage, le réseau, la sécurité et les ports, et propose des tests interactifs pour le clavier, l'écran, le son, le micro, la caméra, le trackpad, la vitesse du disque, etc. Les résultats s'exportent en rapport PDF ou PNG.

> Confidentialité : MacCheck fonctionne entièrement sur votre Mac et n'envoie jamais de numéro de série, de résultat ni de rapport. Les captures de ce README proviennent d'appareils réels (interface chinoise d'origine), avec les numéros de série masqués.

![Vue d'ensemble MacCheck](docs/assets/overview-demo.png)

## Nouveautés de ce fork (v1.0.0)

**Interface en trois langues.** English, Français et 简体中文, modifiable à tout moment dans **Réglages → Langue de l'interface**, ou suivant automatiquement la langue de macOS. Rapports, résultats, demandes d'autorisation et noms d'appareils (ex. « MacBook Pro (14 pouces, 2021) ») sont traduits.

**Test du clavier pour les claviers de tous les pays.**
- Détection automatique du type physique de clavier : **ANSI** (américain), **ISO** (français, allemand, britannique, espagnol, italien, nordique…) ou **JIS** (japonais), avec la bonne forme de touche Entrée, la touche ISO supplémentaire et les touches JIS.
- Les caractères des touches sont lus depuis les dispositions installées dans macOS : **AZERTY, QWERTZ, espagnol, suisse, belge, nordique, russe** et toutes les autres dispositions s'affichent correctement. Vous pouvez aussi choisir une disposition manuellement.
- Cliquez sur une touche pour la valider manuellement (touches interceptées par le système) ou la marquer comme absente sur ce Mac.

**Corrections des problèmes signalés sur le projet d'origine.**

| Issue d'origine | Correction |
| --- | --- |
| [#1](https://github.com/andyhuo520/MacCheck/issues/1) Ne s'ouvre pas sur les Mac Intel | La version Release est désormais un **binaire universel** (Apple Silicon + Intel), et le script de publication refuse d'empaqueter s'il manque une architecture. Les températures et ventilateurs sont aussi lus sur Mac Intel. |
| [#2](https://github.com/andyhuo520/MacCheck/issues/2) Détection MDM renforcée | Détecte le **contournement MDM** courant : serveurs d'inscription d'Apple (`deviceenrollment.apple.com`, `mdmenrollment.apple.com`, `iprofiles.apple.com`…) redirigés vers `0.0.0.0` dans `/etc/hosts`, ainsi que les fichiers marqueurs falsifiés laissés par les scripts de contournement. |
| [#3](https://github.com/andyhuo520/MacCheck/issues/3) Langue anglaise | Interface et README en anglais (et en français). |
| [#4](https://github.com/andyhuo520/MacCheck/issues/4) Volume lu/écrit via `smartctl` | Nouveau contrôle « Durée de vie et volume écrit du disque » : total écrit/lu, durée de vie utilisée, heures sous tension, arrêts non sécurisés et erreurs de support. Nécessite [smartmontools](https://www.smartmontools.org) (`brew install smartmontools`) ; sinon, le contrôle explique comment l'installer. |
| [#5](https://github.com/andyhuo520/MacCheck/issues/5) F11 / fausses touches bloquées, SSD Thunderbolt non détecté, haut de l'écran non testé | ⌘, verr. maj et les autres touches de modification ne sont plus signalées à tort comme « bloquées » ; les fonctions F1–F12 (luminosité, volume…) sont rattachées à leur touche F. Le test des ports détecte désormais les **périphériques Thunderbolt / USB4 et les disques externes**. Les tests du clavier et de l'écran s'ouvrent dans une vraie **fenêtre plein écran couvrant tout l'écran**, y compris la barre des menus et la zone autour de l'encoche ; appuyez sur **H** pour masquer le panneau du test d'écran. |

Également corrigé : la vérification anti-falsification du nombre de cycles de batterie n'apparaissait jamais dans le rapport.

## Fonctionnalités

- Modèle, puce, mémoire, version de macOS, numéro de série et année du modèle
- Cycles et santé de la batterie, stockage, réseau, Bluetooth et ports
- Contrôles à risque pour l'occasion : MDM (avec détection du contournement), identifiant Apple / verrouillage d'activation, puce de sécurité
- Tests interactifs : clavier (touche par touche), écran (couleurs unies / dégradé / damier), haut-parleurs, micro, caméra, Touch ID, trackpad
- Test de vitesse du disque, test de charge avec températures et ventilateurs, test port par port
- Estimation des modèles d'IA locaux utilisables selon la mémoire
- Export du rapport en PDF / PNG en un clic et historique pour comparer plus tard
- Apparence claire, sombre ou système

![Caractéristiques MacCheck](docs/assets/hardware-specs-real.png)

## Configuration requise

- macOS 14.0 ou ultérieur
- Mac Apple Silicon ou Intel
- Xcode 16 ou ultérieur pour compiler depuis les sources
- Facultatif : [`xcodegen`](https://github.com/yonaskolb/XcodeGen) pour régénérer le projet Xcode depuis `project.yml`
- Facultatif : [`smartmontools`](https://www.smartmontools.org) pour les données de durée de vie du disque (`brew install smartmontools`)

## Installation

1. Téléchargez `MacCheck-IM-x.y.z.dmg` depuis la page **[Releases](https://github.com/Davina-01/MacCheck/releases/latest)**. Le même fichier fonctionne sur les Mac Apple Silicon et Intel.
2. Ouvrez le DMG et glissez `MacCheck.app` dans `Applications`.
3. Les autorisations (caméra, micro, Bluetooth) sont demandées au besoin.

Le DMG est compilé automatiquement par GitHub Actions et signé ad hoc (pas encore de signature Developer ID ni de notarisation Apple) : macOS affichera donc un avertissement au premier lancement.

Si macOS indique que l'app « ne peut pas être ouverte car le développeur ne peut pas être vérifié », faites un clic droit sur `MacCheck.app` puis **Ouvrir**. Si macOS indique que l'app « est endommagée », c'est généralement l'attribut de quarantaine du téléchargement ; après avoir déplacé l'app dans `/Applications`, exécutez :

```bash
sudo xattr -rd com.apple.quarantine /Applications/MacCheck.app
```

## Utilisation

1. Ouvrez MacCheck et attendez la fin de l'analyse automatique sur la page Vue d'ensemble.
2. Lisez d'abord la **Vue d'ensemble** et les **Problèmes critiques** ; les éléments rouges sont prioritaires.
3. Passez chaque test de la section **Tests matériels** (clavier, écran, son, caméra…).
4. Cliquez sur **Enregistrer dans l'historique** pour conserver un instantané de l'inspection.
5. Cliquez sur **Exporter le rapport** et choisissez PNG ou PDF.

![Contrôles de sécurité MacCheck](docs/assets/security-real.png)

![Test du clavier MacCheck](docs/assets/testing-demo.png)

## Compiler depuis les sources

```bash
git clone https://github.com/Davina-01/MacCheck.git
cd MacCheck

# Facultatif : seulement si vous avez modifié project.yml
brew install xcodegen
xcodegen generate

# Compilation universelle (Apple Silicon + Intel)
xcodebuild \
  -project MacCheck.xcodeproj \
  -scheme MacCheck \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build_release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO

# Vérifier la présence des deux architectures
lipo -archs build_release/Build/Products/Release/MacCheck.app/Contents/MacOS/MacCheck
```

L'app est générée dans `build_release/Build/Products/Release/MacCheck.app`.

## Créer un DMG

```bash
./scripts/build_and_notarize.sh
```

Le script régénère le projet si `xcodegen` est installé, compile un binaire Release universel et vérifie les deux architectures, signe et fait notariser l'app si un certificat Developer ID est disponible (sinon il produit un DMG ad hoc pour un usage local), puis écrit `dist/MacCheck-IM-1.0.0.dmg`.

Pour une distribution publique, configurez :

```bash
export MACCHECK_SIGN_ID="Developer ID Application: Votre Nom (TEAMID)"
export MACCHECK_NOTARY_PROFILE="maccheck-notary"
```

et enregistrez les identifiants de notarisation avec `xcrun notarytool store-credentials`.

## Numéros de version

- Version de l'app (affichée dans macOS) : `x.y.z` en chiffres uniquement, comme l'exige Apple. Ce fork a sa propre numérotation, qui commence à 1.0.0 (indépendante de celle du projet d'origine).
- Version innomicro.fr : tag Git `vX.Y.Z-im`, fichier `MacCheck-IM-X.Y.Z.dmg`, release « MacCheck IM X.Y.Z ».
- Règle : correctif → `1.0.1`, nouvelle fonctionnalité → `1.1.0`, changement majeur → `2.0.0`.

## Traductions

La langue source est le chinois simplifié : chaque texte de l'interface est écrit en chinois dans le code et récupéré via `L("…")`. Les traductions se trouvent dans :

```text
Sources/Resources/en.lproj/Localizable.strings
Sources/Resources/fr.lproj/Localizable.strings
```

Les marqueurs comme `{0}` et `{1}` doivent être conservés dans les traductions (leur ordre peut changer). Les corrections sont les bienvenues par pull request.

## Structure du projet

```text
Sources/
  App/                 Point d'entrée de l'app et Info.plist
  Core/                Détection matérielle, rapports, historique, services système, localisation
  Checks/              Clavier, écran, son, caméra et autres tests interactifs
  UI/                  Vues SwiftUI, système de design et navigation
  Resources/           Traductions (en, fr) et demandes d'autorisation localisées
scripts/
  build_and_notarize.sh
docs/
  TESTING.md
  RELEASE.md
  assets/
```

## Avertissement et limitation de responsabilité

- **Logiciel fourni « en l'état ».** MacCheck est distribué gratuitement, sans aucune garantie, expresse ou implicite, notamment quant à l'exactitude des résultats, à l'absence de bugs ou à l'adéquation à un usage particulier. Cette version modifiée est encore en cours de débogage.
- **Résultats indicatifs uniquement.** Les résultats ne remplacent ni l'inspection d'un professionnel, ni les vérifications officielles d'Apple (couverture de garantie, verrouillage d'activation, réparations). Certaines anomalies peuvent ne pas être détectées, par exemple une inscription MDM contournée par une méthode inconnue, des pièces non d'origine ou des données falsifiées. Un résultat « normal » ne garantit pas l'état réel de l'appareil.
- **Pas une certification.** Les rapports générés par MacCheck ne constituent ni un certificat, ni une expertise, ni une garantie délivrés par innomicro.fr ou par les auteurs.
- **Tests matériels.** Certains tests sollicitent la machine : le test de disque écrit puis supprime un fichier temporaire de 1 Go, le test de charge fait chauffer le processeur. Sauvegardez vos données avant utilisation ; vous utilisez ces tests à vos propres risques.
- **Responsabilité.** Dans toute la mesure permise par la loi applicable, ni l'auteur du projet d'origine, ni les contributeurs, ni innomicro.fr ne sauraient être tenus responsables d'un dommage direct ou indirect résultant de l'utilisation de ce logiciel, notamment d'une décision d'achat ou de vente, d'une perte de données ou d'un dommage matériel. Cette clause ne limite pas les droits dont vous bénéficiez de manière impérative en tant que consommateur.
- **Projet d'origine.** L'auteur du projet d'origine (andyhuo520) n'est pas responsable des modifications apportées dans cette version.
- **Marques.** Ce projet n'est ni affilié à Apple Inc., ni approuvé ou sponsorisé par elle. Apple, Mac, MacBook, macOS, Touch ID et Thunderbolt sont des marques d'Apple Inc. ou de leurs propriétaires respectifs.
- **Données.** L'application fonctionne entièrement en local ; aucune donnée n'est envoyée à innomicro.fr ni à des tiers.

## Crédits

- Application d'origine : **[andyhuo520/MacCheck](https://github.com/andyhuo520/MacCheck)** par andyhuo520
- Version multilingue et multi-dispositions : **[Davina-01/MacCheck](https://github.com/Davina-01/MacCheck)**, maintenue par **[innomicro.fr](https://innomicro.fr)**, avec l'aide de l'IA
