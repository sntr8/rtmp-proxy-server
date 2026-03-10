# Kanaliiga RTMP Proxy

Kanaliigan RTMP Proxy -palvelin toimii välityspalvelimena casterin ja Twitchin välissä. Palvelin antaa Kanaliigalle mahdollisuuden hallinnoida kanaville lähetettäviä lähetyksiä, lisätä viivettä striimeihin ja hallita mainosnäyttöjä. Castereiden ei tarvitse jakaa Twitch-lähetysavaimiaan, vaan jokainen saa henkilökohtaisen lähetysavaimen järjestelmään.

## Palvelin

Osoite: `stream.kanaliiga.fi`
Tunnukset: Kysy tunnuksia Discordissa

## Lähdekoodit

Palvelun lähdekoodit ovat tarjolla GitLab-projektissa:

Osoite: https://gitlab.com/kanaliiga/stream-rtmp

# Palvelun rakenne

Palvelu on rakennettu Dockerin päälle ja se koostuu useammasta kontista.

## Konttihierarkia

Palvelun toiminnan kannalta välttämättömät **peruskontit** ovat: **haproxy**, **mysql**, **php-fpm** ja **nginx-http**. Kaikkien näiden neljän kontin on oltava päällä, jotta palvelu toimii oikein.

**Striimikontit** luodaan dynaamisesti per casteri tarpeen mukaan. Jokaiselle casterille voidaan luoda:
- **nginx-rtmp-\<caster\>**: Pelistriimikontti, joka lähettää striimin Twitchiin viiveellä tai ilman.
- **nginx-rtmp-proxy-\<caster\>**: Välityspalvelinkontti (proxy), joka ei lähetä Twitchiin, vaan toimii ainoastaan sisäisenä välityspalvelimena.

Kontit ladataan GitLabin säilörekisteristä (container registry) käyttäen kontin versionumeroa ympäristömuuttujista. Versiot asetetaan Ansiblella tai käsin palvelimen ympäristömuuttujiksi.

### haproxy

HAProxy toimii palvelun edustana ja DMZ:na. Ainoastaan HAProxy (sekä SSH-portti) on palvelimesta avoinna ulkomaailmaan. HAProxy ohjaa RTMP-liikenteen oikeille nginx-rtmp-konteille portin perusteella.

Jokaiselle kanavalle on määritetty oma portti (48001-48010 pelistriimit, 48101-48110 proxy-striimit). HAProxyn konfiguraatio päivitetään dynaamisesti, kun kontteja käynnistetään tai sammutetaan `haproxy_configmod`-skriptillä.

**HUOM:** HAProxy tukee pehmeitä uudelleenlatauksia (graceful reload, HUP-signaali), joka siirtää vanhat yhteydet uuteen prosessiin ennen vanhan sammuttamista. Konfiguraatiomuutokset eivät siis katkaise käynnissä olevia striimejä.

### mysql

MySQL-kontti tarjoaa palvelun tietokannan. Tietokannassa on neljä päätaulua: **casters**, **channels**, **games** ja **streams**.

#### casters

Taulussa ovat kaikki casterit, joilla on oikeus käyttää palvelua. Lisäksi taulussa on kaksi sisäistä teknistä käyttäjää:
- **internal_technical_user**: Käytetään viiveen kanssa toimivien konttien sisäisessä kommunikaatiossa.
- **vlc_viewer**: Käytetään, kun katsoja haluaa katsella striimiä VLC:llä ilman viivettä.

| Kenttä | Tyyppi | Kuvaus | Esimerkki |
|-|-|-|-|
| id | bigint | Automaattisesti generoitu ID | 1 |
| nick | varchar(255) | Casterin nimimerkki | JohnDoe |
| stream_key | varchar(255) | Casterin henkilökohtainen lähetysavain. Generoidaan automaattisesti casteria luotaessa. | JohnDoe-abc123def456 |
| discord_id | varchar(255) | Casterin Discord ID (pitkä numerosarja, ei nick#1234). Saadaan Discord-kehittäjätilassa käyttäjää oikeaklikkaamalla. | 123456789012345678 |
| active | boolean | Onko casterilla oikeus lähettää. Asetetaan automaattisesti arvoon true kun kontti käynnistyy, false kun kontti sammutetaan. | true |
| internal | boolean | Onko kyseessä sisäinen tekninen käyttäjä. | false |
| date_added | datetime | Päivämäärä, jolloin käyttäjä lisättiin. | 2021-06-15 14:25:00 |

#### channels

Taulussa ovat kanavat, joille lähetyksiä voidaan ohjata. Kanavat jakaantuvat kahteen tyyppiin:
- **Twitch-kanavat** (kanaliigatv, kanaliigatv2, kanaliigatv3, kanaliigabot): Oikeat Twitch-kanavat, joille voidaan lähettää.
- **Proxy-kanavat** (kanaliigatv1-proxy, only1-proxy, jne.): Sisäiset välityskanavat, jotka eivät lähetä Twitchiin.

| Kenttä | Tyyppi | Kuvaus | Esimerkki |
|-|-|-|-|
| id | bigint | Automaattisesti generoitu ID | 1 |
| name | varchar(255) | Kanavan tekninen nimi. Twitch-kanaville sama kuin kirjautumistunnus. | kanaliigatv |
| display_name | varchar(255) | Kanavan näyttönimi | KanaliigaTV |
| access_token | varchar(255) | Twitch Helix API:n pääsytunnus (vain Twitch-kanaville). | WOYkPWbdf1sMgdAUxhti7dhET6wWPS7 |
| client_id | varchar(255) | Twitch API client ID (vain Twitch-kanaville). | gp762nuuoqcoxypju8c569th9wz7q5 |
| refresh_token | varchar(255) | Tunnus, jolla access_token voidaan päivittää twitchtokengenerator.com API:lla. | lM6aMXactcfUxf0jXViNfzrHX6URxkbdbanBTLEqgIFuNDnHqPv |
| access_token_expires | datetime | Milloin access_token vanhenee (max 60 pv). | 2021-06-15 14:25:00 |
| port | int | Kanavan HAProxy-portti (48001-48010 striimit, 48101-48110 proxy). | 48001 |
| url | varchar(255) | Kanavan Twitch-URL | https://www.twitch.tv/kanaliigatv |

#### games

Taulussa on kaikki pelit, joita voidaan lähettää Twitchiin. Pelin `display_name` on täsmättävä täysin Twitchin Helix API:n kanssa, jotta pelin asettaminen onnistuu.

| Kenttä | Tyyppi | Kuvaus | Esimerkki |
|-|-|-|-|
| id | bigint | Automaattisesti generoitu ID | 1 |
| name | varchar(255) | Pelin tekninen nimi (lyhyt, pienillä kirjaimilla). | pubg |
| display_name | varchar(255) | Pelin virallinen nimi Twitchissä (täsmättävä tarkalleen). | PlayerUnknown's Battlegrounds |
| abbreviation | varchar(255) | Pelin virallinen lyhenne | PUBG |
| delay | int | Lähetysviive sekunteina (0 = ei viivettä). | 480 |

#### streams

Taulussa ovat ajastetut lähetykset. Jokainen lähetys tulee ajastaa etukäteen, jotta:
- Kontit käynnistyvät ja sammuvat automaattisesti.
- Casterit saavat Discord-ilmoitukset konttien käynnistymisistä.
- Kanavien päällekkäisyydet voidaan tarkistaa.

| Kenttä | Tyyppi | Kuvaus | Esimerkki |
|-|-|-|-|
| id | bigint | Automaattisesti generoitu ID | 1 |
| caster_id | bigint | Pääcasterin ID (viiteavain casters-tauluun). | 1 |
| cocaster_id | varchar(255) | Toisen casterin ID (lisätty v1.6). | 2 |
| channel_id | bigint | Kanavan ID (viiteavain channels-tauluun). | 1 |
| game_id | bigint | Pelin ID (viiteavain games-tauluun). NULL proxy-lähetyksille. | 1 |
| title | varchar(255) | Twitchiin asetettava striimin otsikko. | Kanaliiga PUBG \| Masters Day 8 \| Casters: JohnDoe & JaneDoe |
| description | text | Lähetyksen kuvaus (ei tällä hetkellä käytössä). | |
| live | boolean | Onko lähetys tällä hetkellä käynnissä. | true |
| skip | boolean | Onko lähetys merkitty ohitettavaksi virheen vuoksi. | false |
| start_time | datetime | Lähetyksen alkamisaika | 2021-06-15 14:25:00 |
| end_time | datetime | Lähetyksen päättymisaika (pakko olla start_time:n jälkeen). | 2021-06-15 16:25:00 |

### nginx-http

nginx-http -kontti tarjoilee kahta eri kontekstia:
1. **/ads/** - Julkinen, tarjoilee mainokset lähetysten käyttöön.
2. **/rtmp/** - Sisäverkko, tarjoilee auth.php-autentikoinnin nginx-rtmp-konteille.

**Turvallisuus:** Pääsy /rtmp/-kontekstiin ulkoverkosta on estetty HAProxyn konfiguraatiossa.

#### /ads/ - Mainoskonteksti

Mainossivu tarjoilee OBS-lähteeksi lisättävän mainoskierron.

**Hakemistorakenne:**
```
nginx-http/html/ads/
├── img/
│   ├── common/          # Yleiset mainokset (kaikissa striimeissä)
│   ├── apex/            # Apex Legends -mainokset
│   ├── csgo/            # CS:GO -mainokset
│   ├── pubg/            # PUBG -mainokset
│   └── rl/              # Rocket League -mainokset
├── ads.php              # Pääsivu
├── carousel.js          # Slick carousel -logiikka
└── style.css
```

**Toiminta:**
- Käyttää [Slick](https://kenwheeler.github.io/slick/)-kuvakarusselia.
- Jokainen mainos näytetään 15 sekuntia.
- URL: `/ads/pelinnimi.php` tai `/ads/ads.php?game=pelinnimi`
- Ilman game-parametria näytetään vain common-mainokset.
- Mainokset sekoitetaan satunnaisesti tasapuolisen mainosajan takaamiseksi.

**Mainoskuvien vaatimukset:**
- Formaatti: `.png` tai `.jpg` (pienet kirjaimet!).
- Sijainti: `img/common/` tai `img/pelinnimi/`

#### /rtmp/ - Autentikointikonteksti

Sisäverkossa toimiva autentikointi nginx-rtmp-konteille. Tarjoilee `auth.php`-tiedoston.

**auth.php - RTMP-autentikointi:**

Jokainen nginx-rtmp-kontille tuleva RTMP-yhteys autentikoidaan tämän kautta. Autentikoinnin vaatimukset:
- Lähetyspolku täsmää aktiiviseen casteriin tietokannassa.
- Lähetysavain täsmää casterin stream_key-kenttään.
- Kutsu on tyyppiä: publish, play tai update.
- Sisäiset käyttäjät (internal=true) eivät voi käyttää publish-kutsua.

**HTTP-vastauskoodit:**

| Koodi | Merkitys |
|-|-|
| 200 | Autentikointi onnistui |
| 400 | RTMP-kutsu ei ole sallittu |
| 401 | Lähetysavain on väärin |
| 404 | Lähetyspolku on väärin |
| 500 | Tietokantavirhe |

### php-fpm

PHP-FPM -kontti suorittaa PHP-koodin nginx-http -kontin puolesta (ads.php ja auth.php).

## Operointiskriptit

Palvelua hallitaan Bash-skripteillä, jotka sijaitsevat `tools/`-hakemistossa:

| Skripti | Tarkoitus |
|-|-|
| **containermod** | Konttien hallinta (käynnistys, sammutus, uudelleenkäynnistys) |
| **streammod** | Striimien ajastus ja hallinta |
| **castermod** | Casterien lisäys ja listaus |
| **channelmod** | Kanavien hallinta |
| **gamemod** | Pelien listaus |
| **haproxy_configmod** | HAProxyn konfigurointi |
| **discordmod** | Discord-ilmoitukset |
| **cron_worker.sh** | Cron-työskripti striimien automaattiseen käynnistykseen/sammutukseen |

### containermod - Konttien hallinta

Tärkein skripti konttien operointiin.

**Kriittiset turvallisuusmekanismit:**
- nginx-http ja php-fpm **eivät voi sammua**, jos mikään nginx-rtmp-kontti on käynnissä.
- Tämä tarkistetaan `/var/lock/nginx-rtmp-*.lock` -tiedostoista.
- nginx-rtmp-kontteja **ei voi käynnistää uudelleen** automaattisesti (käytä stop + start).

**Yleisimmät komennot:**
```bash
# Listaa kaikki kontit
containermod --list

# Käynnistä kaikki peruskontit
containermod --start --all

# Sammuta kaikki peruskontit (epäonnistuu, jos striimejä on käynnissä!)
containermod --stop --all

# Käynnistä kaikki peruskontit uudelleen (epäonnistuu, jos striimejä on käynnissä!)
containermod --restart --all

# Käynnistä yksittäinen peruskontti uudelleen
containermod --restart --name haproxy

# Käynnistä striimikontti
containermod --start --name nginx-rtmp --caster JohnDoe --channel kanaliigatv --game pubg

# Käynnistä proxy-kontti
containermod --start --name nginx-rtmp --caster JohnDoe --channel kanaliigatv1-proxy --proxy

# Sammuta striimikontti
containermod --stop --name nginx-rtmp --caster JohnDoe

# Sammuta proxy-kontti
containermod --stop --name nginx-rtmp --caster JohnDoe --proxy
```

**HUOM:** Jos haluat käynnistää kaiken uudelleen, sinun on ensin sammutettava kaikki nginx-rtmp-kontit:
```bash
# Listaa ensin käynnissä olevat nginx-rtmp-kontit
docker ps | grep nginx-rtmp

# Sammuta jokainen erikseen
containermod --stop --name nginx-rtmp --caster JohnDoe
containermod --stop --name nginx-rtmp --caster JaneDoe --proxy

# Nyt voit käynnistää peruskontit uudelleen
containermod --restart --all
```

### streammod - Striimien hallinta

Striimien ajastus ja hallinta.

**Yleisimmät komennot:**
```bash
# Lisää uusi striimi (interaktiivinen)
streammod --add

# Listaa tulevat striimit
streammod --upcoming

# Listaa käynnissä olevat striimit
streammod --live

# Pidennä striimin päättymisaikaa
streammod --extend <stream_id>

# Poista striimi
streammod --delete <stream_id>
```

**HUOM:** Striimit tulisi aina ajastaa etukäteen! Tämä varmistaa:
- Automaattisen käynnistyksen/sammutuksen cron_workerillä.
- Discord-ilmoitukset castereille.
- Ei päällekkäisiä varauksia samalle kanavalle.

### castermod - Casterien hallinta

Casterien lisäys ja listaus.

**Komennot:**
```bash
# Lisää uusi casteri (generoi automaattisen stream keyn)
castermod --add <nick> <discord_id>

# Lisää casteri tietyllä stream keylla
castermod --add <nick> <discord_id> --key <stream_key>

# Listaa kaikki casterit
castermod --list

# Listaa vain nickit
castermod --list --nicks

# Aktivoi casteri (asettaa active=true)
castermod --activate <nick>

# Deaktivoi casteri (asettaa active=false)
castermod --disable <nick>
```

**Discord ID:n hakeminen:**
1. Discord > Settings > Advanced > Developer Mode (päälle)
2. Oikeaklikkaa käyttäjää > Copy User ID
3. ID on pitkä numerosarja, **ei** muotoa nick#1234.

### haproxy_configmod - HAProxyn konfigurointi

HAProxyn konttireititysten hallinta. **Käytetään yleensä automaattisesti** `containermod`-skriptin toimesta.

```bash
# Lisää reititys casterille
haproxy_configmod --add <caster> <channel>

# Poista reititys
haproxy_configmod --remove <caster>
```

**HUOM:** Muutokset vaativat HAProxyn uudelleenlatauksen (reload), mutta pehmeä uudelleenlataus ei katkaise käynnissä olevia striimejä (HUP-signaali siirtää yhteydet uuteen prosessiin).

# Ansible

Palvelimen konfigurointi tapahtuu Ansiblella. Ansible-konfiguraatiot määrittelevät:
- Palvelimen ympäristömuuttujat (versiot, salasanat, API-avaimet).
- Cron-työt striimien automaattiseen käynnistykseen.
- Käyttöoikeudet ja turvallisuusasetukset.

Ansible-konfiguraatiot sijaitsevat `ansible/`-hakemistossa.

---

# Päivittäiset operaatiot

## Striimin ajastaminen

**Striimit tulee AINA ajastaa etukäteen!** Tämä varmistaa automaattisen käynnistyksen/sammutuksen sekä Discord-ilmoitukset.

```bash
streammod --add
```

Komento kysyy interaktiivisesti:
- **Casteri:** Pääcasterin nimimerkki (nick)
- **Ko-casteri:** Toisen casterin nimimerkki (valinnainen, v1.6+)
- **Kanava:** Twitch-kanava tai proxy-kanava
- **Peli:** Pelin nimi (ei tarvita proxy-konteille)
- **Otsikko:** Twitchiin asetettava striimin otsikko
- **Alkamisaika:** Formaatti `DD.MM.YYYY HH:MM` (ei voi olla menneisyydessä)
- **Päättymisaika:** Formaatti `DD.MM.YYYY HH:MM` (pakko olla alkamisajan jälkeen)

**HUOM:** Skripti ei automaattisesti tarkista päällekkäisiä varauksia! Tarkista käsin: `streammod --upcoming`

## Striimien hallinta

```bash
# Listaa tulevat striimit
streammod --upcoming

# Listaa käynnissä olevat striimit
streammod --live

# Pidennä striimin päättymisaikaa
streammod --extend <stream_id>

# Poista tuleva striimi
streammod --delete <stream_id>
```

## Casterin lisääminen

```bash
castermod --add <nick> <discord_id>
```

**Discord ID:n hakeminen:**
1. Discord > Asetukset > Lisäasetukset > Kehittäjätila (päälle)
2. Oikeaklikkaa käyttäjää > Kopioi käyttäjän ID
3. ID on pitkä numerosarja (esim. `123456789012345678`), **EI** muotoa nick#1234.

## Hätäkäynnistys käsin

**VAROITUS:** Käsin käynnistettyjä kontteja ei oteta huomioon ajastuksissa! Kontit on myös sammutettava itse käsin tai palvelun automaattinen toiminta lakkaa. Käytä vain hätätilanteissa.

```bash
# Katso ensin tarvittavat arvot
castermod --list --nicks
channelmod --list
gamemod --list

# Käynnistä striimikontti
containermod --start --name nginx-rtmp --caster <CASTER> --channel <CHANNEL> --game <GAME>

# Käynnistä proxy-kontti
containermod --start --name nginx-rtmp --caster <CASTER> --channel <PROXY_CHANNEL> --proxy

# Sammuta striimikontti
containermod --stop --name nginx-rtmp --caster <CASTER> --channel <CHANNEL>

# Sammuta proxy-kontti
containermod --stop --name nginx-rtmp --caster <CASTER> --channel <PROXY_CHANNEL> --proxy
```

## Mainosten päivittäminen

**VAROITUS:** nginx-http- ja php-fpm-kontit eivät voi sammua striimien aikana! Päivitä mainokset ennen striimejä.

### 1. Lisää mainoskuvat GitLabiin

```bash
git clone [https://gitlab.com/kanaliiga/stream-rtmp.git](https://gitlab.com/kanaliiga/stream-rtmp.git)
cd stream-rtmp
git checkout -b ads/yrityksen-nimi

# Kopioi .png- tai .jpg-kuvat oikeaan hakemistoon:
# nginx-http/html/ads/img/common/ (yleiset mainokset)
# nginx-http/html/ads/img/pubg/ (pelikohtaiset)
# nginx-http/html/ads/img/csgo/
# nginx-http/html/ads/img/rl/
# nginx-http/html/ads/img/apex/

git add nginx-http/html/ads/img/
git commit -m "Add ads for YritysOy"
git push -u origin ads/yrityksen-nimi
```

### 2. Luo Merge Request GitLabissa

Pyydä koodikatselmointi (code review) ja odota hyväksyntää.

### 3. Koosta Docker-imaget (master-haarassa)

```bash
git checkout master
git pull
./tools/build_all_images.sh $IMAGE_VERSION
```

Koostaminen (build) kestää 5-10 minuuttia internet-yhteydestä riippuen.

### 4. Päivitä kontit palvelimella

**Tarkista ENSIN, ettei striimejä ole käynnissä:**

```bash
# Tarkista käynnissä olevat nginx-rtmp-kontit
containermod --list

# Jos nginx-rtmp-kontteja näkyy, ÄLÄ jatka!
# Odota, että striimit päättyvät tai sovi asiasta niiden castereiden kanssa.

# Jos ei nginx-rtmp-kontteja ole käynnissä, voit päivittää:
containermod --stop --name nginx-http
containermod --stop --name php-fpm
containermod --start --name php-fpm
containermod --start --name nginx-http
```

# Vianmääritys

## "Connection failed to server" (OBS)

**Oire:** OBS ei saa yhteyttä RTMP-palvelimeen.

**Mahdolliset syyt:**

### 1. Tarkista OBS-asetukset

```
Server: rtmp://stream.kanaliiga.fi/<caster>/
Stream Key: <caster>-<stream_key>
```

**Oikea portti:** OBS yhdistää HAProxyyn, joka ohjaa liikenteen oikealle portille. **ÄLÄ** laita porttia OBS:n Server-kenttään.

### 2. Tarkista, että HAProxy on käynnissä

```bash
containermod --list | grep haproxy
```

Jos ei näy, käynnistä se:
```bash
containermod --start --name haproxy
```

### 3. Tarkista, että nginx-rtmp-kontti on käynnissä

```bash
containermod --list | grep nginx-rtmp-<caster>
```

Jos ei näy, tarkista:
- Onko striimi ajastettu? `streammod --live`
- Käynnistä käsin, jos on tarpeellista (katso hätäkäynnistys).

### 4. Tarkista, että casteri on aktiivinen

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT nick, active, stream_key FROM casters WHERE nick='<caster>'"
```

Kentän `active` pitää olla `1`. Jos se on `0`:
```bash
castermod --activate <caster>
```

### 5. Testaa yhteys palvelimeen

```bash
# Omalta koneelta
telnet stream.kanaliiga.fi 1935

# Pitäisi yhdistää. Jos ei yhdistä, kyseessä on verkko-ongelma tai HAProxy ei kuuntele.
```

## OBS lähettää, mutta ei lähetystä Twitchissä

### 1. Tarkista, että nginx-rtmp-kontti on käynnissä

```bash
containermod --list
```

Listauksessa pitäisi näkyä `nginx-rtmp-<caster>` tai `nginx-rtmp-proxy-<caster>`.

### 2. Tarkista HAProxy-konfiguraatio

```bash
cat /opt/haproxy/haproxy.cfg
```

Jokaiselle casterille pitäisi olla oma lohko:

```
# ::JohnDoe::start
frontend rtmp-kanaliigatv
    bind *:48001
    mode tcp
    default_backend JohnDoe

backend JohnDoe
    server nginx-rtmp-JohnDoe nginx-rtmp-JohnDoe:1935 check
# ::JohnDoe::end
```

**Ongelmat:**
- Useampi konfiguraatiomääritys samalle casterille.
- Puutteelliset lohkot (vain `::start` tai vain `::end`).
- Konfiguraatio on olemassa casterille, jolla ei ole konttia käynnissä.

**Korjaus 1 - Editoi käsin (suositeltu):**

```bash
# Editoi konfiguraatiota käsin
nano /opt/haproxy/haproxy.cfg

# Poista duplikaatit/virheelliset lohkot.
# Varmista, että jokaisella käynnissä olevalla kontilla on oikea lohko.

# HAProxyn uudelleenlataus (pehmeä, ei katkaise striimejä)
docker kill -s HUP haproxy
```

**Korjaus 2 - Uudelleengeneroi konfiguraatio:**

```bash
# HUOM: Tämä uudelleenkäynnistys sammuttaa HAProxyn hetkeksi, mikä voi aiheuttaa lyhyen katkoksen.
containermod --restart --name haproxy

# Lisää konfiguraatio jokaiselle käynnissä olevalle kontille.
haproxy_configmod --add <CASTER> <CHANNEL>
# Esim:
haproxy_configmod --add JohnDoe kanaliigatv
```

### 3. Tarkista Twitch Stream Key

**Mitä tapahtuu:** Kontin käynnistyessä järjestelmä hakee Twitchin lähetysavaimen (stream key) Helix API:sta ja konfiguroi ffmpeg:n lähettämään siihen. Jos haku epäonnistuu, avain jää "Null"-tilaan eikä striimiä lähetetä Twitchiin.

**Tarkista konfiguraatio:**

```bash
docker exec nginx-rtmp-<CASTER> cat /etc/nginx/nginx.conf | grep exec_push
```

**Pitäisi näyttää tältä:**
```
exec_push ffmpeg ... rtmp://osl.contribute.live-video.net/app/live_XXXXXXXXXXX;
```

(Palvelin `osl` voi olla myös `hel`, `cph` tai `arn` – Twitchin ingest-serveri).

**Jos näkyy `Null` lähetysavaimen paikalla:**

Tämä tarkoittaa, että Twitch API -kutsu epäonnistui kontin käynnistyksessä. Syitä tähän voivat olla:
- Twitch access token on vanhentunut (katso kohta 4).
- Twitch API oli alhaalla.
- Tietokannassa on väärä kanavan nimi (channel name).

**Korjaus:**

```bash
# Sammuta ja käynnistä kontti uudelleen (järjestelmä hakee lähetysavaimen uudestaan)
containermod --stop --name nginx-rtmp --caster <CASTER>
containermod --start --name nginx-rtmp --caster <CASTER> --channel <CHANNEL> --game <GAME>

# Tarkista Docker-lokit, jos ongelma jatkuu:
docker logs nginx-rtmp-<CASTER> | grep -i "stream.*key\|twitch\|api"
```

### 4. Tarkista Twitch API -tokenit

Twitchin pääsytunnukset (access tokenit) vanhenevat 60 päivän välein. Järjestelmä yrittää automaattisesti päivittää (refresh) tokenit käyttäen `refresh_token`-avainta.

**Tarkista tokenien tila:**

```bash
# Katso milloin tokenit vanhenevat
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "SELECT name, access_token_expires FROM channels WHERE name NOT LIKE '%proxy%'"
```

**Jos lähetysavaimen haku epäonnistuu:**

1. Järjestelmä yrittää automaattisesti päivittää tokenit.
2. Jos päivitys epäonnistuu, castereille lähetetään Discord-ilmoitus.
3. **Manuaalinen korjaus tarvitaan, jos:**
   - `refresh_token` on vanhentunut tai virheellinen.
   - Twitch API -tunnukset (credentials) ovat muuttuneet.

**Hae uudet tokenit:**

1. Mene osoitteeseen: https://twitchtokengenerator.com
2. Kirjaudu sisään kanavalle.
3. Hae uudet avaimet: `access_token`, `refresh_token` ja `client_id`.
4. Päivitä ne tietokantaan:

```bash
docker exec mysql mysql --defaults-extra-file=/creds.cnf -e \
  "UPDATE channels SET
   access_token='NEW_ACCESS_TOKEN',
   refresh_token='NEW_REFRESH_TOKEN',
   client_id='NEW_CLIENT_ID',
   access_token_expires=DATE_ADD(NOW(), INTERVAL 60 DAY)
   WHERE name='kanaliigatv'"
```

## SSL/TLS-yhteysvirhe (HTTPS)

**Oire:** Selaimessa näkyy "Your connection is not private" tai "SSL_ERROR_EXPIRED_CERT", kun yritetään avata https://stream.kanaliiga.fi

**Syy:** Let's Encrypt -varmenteet vanhenevat 90 päivän välein. HAProxyn pitäisi uusia ne automaattisesti, mutta joskus uusinta epäonnistuu.

### Tarkista varmenteen vanheneminen

```bash
# Tarkista nykyisen varmenteen voimassaolo
openssl x509 -in /opt/letsencrypt/live/stream.kanaliiga.fi/cert.pem -noout -dates

# Tai selaimesta: Klikkaa lukon ikonia > Certificate > Valid from/to
```

### Korjaa vanhentuneet varmenteet

```bash
# Poista vanhat varmenteet
rm -rf /opt/letsencrypt/*

# Käynnistä HAProxy uudelleen - se hakee automaattisesti uuden Let's Encrypt -varmenteen
containermod --restart --name haproxy

# Odota hetki ja tarkista, että varmenteet luotiin onnistuneesti
ls -la /opt/letsencrypt/live/stream.kanaliiga.fi/
```

## Kontit eivät sammu (`containermod --restart --all` epäonnistuu)

**Oire:** Komento `containermod --restart --all` tai `--stop --all` epäonnistuu virheilmoituksella "A stream container is running. Can't stop nginx-http/php-fpm at this time".

**Syy:** Turvallisuusmekanismi - nginx-http ja php-fpm -kontit eivät voi sammua, kun nginx-rtmp-kontteja on käynnissä. Tämä johtuu siitä, että nginx-rtmp-kontit tarvitsevat niitä autentikointiin (auth.php) ja mainosten näyttämiseen.

### Ratkaisu

```bash
# 1. Listaa kaikki käynnissä olevat nginx-rtmp-kontit
containermod --list | grep nginx-rtmp

# Esimerkki outputista:
# nginx-rtmp-JohnDoe
# nginx-rtmp-proxy-AliceSmith
# nginx-rtmp-BobJones

# 2. Sammuta jokainen nginx-rtmp-kontti erikseen
containermod --stop --name nginx-rtmp --caster JohnDoe
containermod --stop --name nginx-rtmp --caster AliceSmith --proxy
containermod --stop --name nginx-rtmp --caster BobJones

# 3. Varmista, että kaikki nginx-rtmp-kontit on sammutettu
containermod --list | grep nginx-rtmp
# Tulosteen pitäisi olla tyhjä.

# 4. Tarkista, että lock-tiedostot on poistettu
ls -la /var/lock/nginx-rtmp-*.lock 2>/dev/null
# Tulosteen pitäisi olla tyhjä tai näyttää "No such file".

# 5. Nyt voit käynnistää peruskontit uudelleen
containermod --restart --all

# 6. Käynnistä nginx-rtmp-kontit takaisin tarpeen mukaan
# (tai anna cron_workerin hoitaa homma, jos ne on ajastettu)
```

## Muu ongelma / Yleinen debuggaus

Jos mikään yllä olevista ei auta, käy läpi nämä vaiheet:

### 1. Tarkista Docker-lokit

```bash
# Tarkista viimeisimmät lokit
docker logs --tail 100 <container_name>

# Esim. nginx-rtmp-kontin lokit
docker logs --tail 100 nginx-rtmp-JohnDoe

# Seuraa lokeja reaaliajassa
docker logs -f nginx-rtmp-JohnDoe

# Etsi virheitä
docker logs nginx-rtmp-JohnDoe | grep -i "error\|fail\|exception"
```

### 2. Tarkista konttien tila

```bash
# Listaa kaikki kontit (myös pysähtyneet)
docker ps -a

# Tarkista kontin terveys
docker inspect haproxy | grep -A 10 "State"

# Katso milloin kontti käynnistyi / sammui
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 3. Tarkista palvelimen resurssit

```bash
# Levytila (pitäisi olla vähintään 10% vapaana)
df -h

# Muisti (jos swap on käytössä, muisti on lopussa)
free -h

# CPU ja muisti per kontti
docker stats --no-stream

# Järjestelmän kuormitus
uptime
```

### 4. Tarkista verkko

```bash
# Docker-verkko
docker network ls
docker network inspect stream

# Porttien kuuntelu
netstat -tlnp | grep -E ":(80|443|1935|48[01][0-9][0-9])"

# Onko HAProxy tavoitettavissa?
curl -I http://localhost:80
```

### 5. Viimeisenä keinona - täysi uudelleenkäynnistys

**VAROITUS:** Tämä katkaisee KAIKKI striimit! Sovi asiasta ensin muiden castereiden kanssa.

```bash
# Sammuta kaikki kontit
docker stop $(docker ps -q)

# Käynnistä Docker-palvelu uudelleen
systemctl restart docker

# Käynnistä peruskontit
containermod --start --all

# Tarkista, että kaikki käynnistyi
containermod --list
```

### 6. Dokumentoi ja pyydä apua

Jos ongelma jatkuu tai löydät uuden vikatilan:
- Ota talteen tarpeelliset lokit.
- Dokumentoi mitä teit ja mitä tapahtui.
- Päivitä tämä wiki uudella ratkaisulla.
- Pyydä apua kokeneemmalta.

---

## Parhaat käytännöt

### Ennen striimejä
- **Aina** ajasta striimit etukäteen: `streammod --add`
- **Tarkista**, ettei päällekkäisyyksiä ole: `streammod --upcoming`
- **Varmista**, että peruskontit ovat käynnissä: `containermod --list`

### Striimien aikana
- **ÄLÄ** käynnistä nginx-http- tai php-fpm-kontteja uudelleen (autentikointi hajoaa).
- **ÄLÄ** sammuta HAProxya full restartilla (pehmeä uudelleenlataus on ok: `docker kill -s HUP haproxy`).
- **ÄLÄ** aja komentoa `containermod --restart --all` (epäonnistuu, jos striimejä on käynnissä).

### Huoltotoimenpiteet
- **Sovi** aina muiden striimaajien kanssa ennen suuria muutoksia.
- **Testaa** ensin staging-ympäristössä, jos mahdollista.
- **Dokumentoi** kaikki tehdyt muutokset ja löydetyt ongelmat.
- **Päivitä** tämä wiki, jos löydät uuden ratkaisun.

### Hätätilanteessa
1. Tarkista Docker-lokit ensin.
2. Googlaa virheilmoitus.
3. Kysy apua Discordissa.
4. Viimeisenä keinona: full restart (katkaisee striimit).