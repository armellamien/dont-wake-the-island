# Don't Wake the Island

Prototype iOS 18+ (Swift 6, SwiftUI, SpriteKit, ActivityKit, SwiftData, Core Haptics, AVFoundation).

## Générer et lancer le projet (Mac requis)

```bash
brew install xcodegen
cd DontWakeTheIsland
xcodegen generate
open DontWakeTheIsland.xcodeproj
```

Dans Xcode : choisir ton équipe dans *Signing & Capabilities* pour les deux cibles (`DontWakeTheIsland` et `IslandWidgetExtension`), puis lancer sur un iPhone ou un simulateur iPhone 15/16/17 Pro (Dynamic Island) ou iPhone SE (sans Dynamic Island).

> Le dossier s'appelle `DontWakeTheIsland` et non `Don'tWakeTheIsland` : une apostrophe dans un nom de cible ou de module casse la compilation Swift.

### Sans XcodeGen

1. Nouveau projet iOS App « DontWakeTheIsland » (SwiftUI, Swift, stockage : None).
2. Glisser le dossier `DontWakeTheIsland/` dans le projet (cible app), **en retirant** `IslandLiveActivity.swift` et `IslandWidgetBundle.swift` de la cible app.
3. *File > New > Target > Widget Extension* nommée `IslandWidgetExtension`, cocher « Include Live Activity », supprimer les fichiers générés et y ajouter `IslandAttributes.swift`, `IslandLiveActivity.swift`, `IslandWidgetBundle.swift`.
4. Dans l'Info.plist de l'app : `NSSupportsLiveActivities = YES`, `CADisableMinimumFrameDurationOnPhone = YES`, schéma d'URL `dontwaketheisland`, orientation portrait uniquement.
5. Build Settings : Swift Language Version 6, iOS Deployment Target 18.0.

## Compiler et tester sans Mac (GitHub Actions + TestFlight)

Le workflow [.github/workflows/ios.yml](.github/workflows/ios.yml) tourne sur les Mac de GitHub.

**1. Compilation (gratuite, sans compte Apple)** : à chaque `git push`, le projet est compilé pour le simulateur. En cas d'échec, les erreurs s'affichent dans l'onglet *Actions*, et le fichier `errors.txt` se télécharge dans *Artifacts*.

**2. Envoi sur TestFlight (compte Apple Developer à 99 €/an)** :
1. Sur [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list), crée l'identifiant d'app (*Identifiers > +*), par exemple `com.tonnom.dontwaketheisland`, puis le second, `com.tonnom.dontwaketheisland.widget`.
2. Sur [App Store Connect](https://appstoreconnect.apple.com), crée l'app (*Apps > + > Nouvelle app*) avec ce même identifiant.
3. Dans *Utilisateurs et accès > Intégrations > Clés d'API App Store Connect*, crée une clé avec le rôle **Admin**. Télécharge le fichier `.p8` (une seule fois possible), puis note son *Key ID* et l'*Issuer ID*.
4. Dans ton dépôt GitHub, ouvre *Settings > Secrets and variables > Actions* et ajoute :
   - `APPLE_TEAM_ID` : ton Team ID (dans *Membership* sur developer.apple.com)
   - `APP_BUNDLE_ID` : `com.tonnom.dontwaketheisland`
   - `ASC_KEY_ID`, `ASC_ISSUER_ID` : les identifiants de la clé
   - `ASC_KEY_P8` : tout le contenu du fichier `.p8`, lignes `BEGIN`/`END` comprises
5. Dans *Actions > iOS > Run workflow*, coche « Envoyer la build sur TestFlight ».
6. Après 10 à 30 minutes de traitement chez Apple, ajoute-toi comme testeur interne dans l'onglet *TestFlight* d'App Store Connect. Installe ensuite l'app **TestFlight** sur l'iPhone : le jeu y apparaît.

Les minutes macOS sont illimitées sur un dépôt **public**. Sur un dépôt privé, le quota gratuit donne environ 200 minutes macOS par mois, soit à peu près 25 à 30 compilations.

## Commandes

| Geste | En sommeil | En chasse | Bruit |
|---|---|---|---|
| Tap | se déplacer / ramasser | se déplacer | +2 |
| Double tap | aimant (attire les pièces proches) | idem | +5 |
| Glisser | esquive rapide | esquive + invulnérabilité courte | +3 |
| Maintenir | « chut » : le bruit baisse, on ne bouge plus | charge un bouclier (0,9 s) | — |
| 4 actions en moins d'1 s | | | +8 |
| 💎 / ⭐️ | gros bonus | | +10 |
| 🌙 | berceuse : −25 de bruit | ralentit la créature | |

Les actions faites près de l'île sont plus bruyantes (jusqu'à ×1,6). Le bruit retombe tout seul au début, puis de moins en moins à mesure que la difficulté monte : la créature finit toujours par se réveiller.

## Score

`pièces × combo × difficulté (× 2 avec ⭐️, × 1,5 en chasse)` + temps de survie × difficulté + bonus (💎, prise de risque quand le bruit dépasse 70 %).

## Dynamic Island : ce qui est fait et pourquoi

iOS n'affiche **pas** la Live Activity d'une app dans la Dynamic Island tant que cette app est au premier plan, et une Live Activity ne peut ni recevoir de gestes de jeu ni être rafraîchie 60 fois par seconde. Le jeu utilise donc deux îles :

1. **L'île dans l'app** (`IslandOverlayView`) : sur les iPhone à Dynamic Island, une capsule noire est dessinée exactement autour de la découpe matérielle, si bien que la vraie île semble s'animer : la créature y dort, respire, tremble, et l'île s'agrandit au réveil (« WHO WOKE ME UP?! »). C'est de là que la créature sort pour te poursuivre, et que partent les ondes de choc. Sur les autres iPhone, la même île s'affiche comme une pastille classique.
2. **La Live Activity** (`IslandLiveActivity`, ActivityKit) : quand tu quittes l'app en pleine partie, le jeu se met en pause et l'île système prend le relais (compact, minimal, étendue avec bouton « Reprendre », écran verrouillé). Elle n'est mise à jour qu'aux changements d'humeur, à la pause/reprise et au game over, ce qui limite les appels à ActivityKit.

La détection repose sur la marge de sécurité supérieure (≥ 55 pt pour les modèles à Dynamic Island). Si les Live Activities sont refusées ou absentes, le jeu reste entièrement jouable.

## Audio

Tous les sons et les deux musiques (berceuse, poursuite) sont synthétisés au lancement dans `AudioService` : aucun fichier audio n'est nécessaire. `Resources/Sounds` est prêt pour de vrais enregistrements.
