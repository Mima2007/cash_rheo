# Cash Rheo — Sažetak za Claude Code sesiju

**Datum sažetka:** 19. april 2026.
**Prethodne sesije:** `cash_rheo_master_plan.md`, `cash_rheo_sazetak_apr19.md` (prva sesija), `cash_rheo_sazetak_apr19_v2.md` (druga sesija)
**Trenutna faza:** Priprema za Android Play Store objavu
**Sledeći korak:** Još jedna provera Google ML Kit skenera, pa release koraci

---

## KONTEKST VLASNIKA PROIZVODA

Mima je preduzetnik iz Bačke Palanke. **Nije programer** ali ima domensku ekspertizu i jasnu biznis viziju. Koristi AI (Claude) kao tehničkog partnera.

**Primarni biznis:** Refakcija akcize za transport firme (kamionske kompanije). App Cash Rheo je **alat u službi primarnog biznisa**, ne primarni proizvod.

**Monetizacija:**
- **B2C (male kancelarije, službenici):** Prisutnost imena na tržištu, prečica za digitalizaciju fiskala — marketing kanal
- **B2B (transport firme):** Pretplata za app + dashboard + **10% od refakcije akcize** (pravi prihod). App daje "gospodski status" klijentima
- NE konkuriše Mani app-i (oni prodaju pretplatu fizičkim licima za praćenje ličnih troškova — drugačiji use-case)

**Način rada:**
- Razgovara pre implementacije
- Kad kaže "ne kodiraj, razgovaramo" — to je **istraživanje mogućnosti**, ne naredba za rad
- Kad kaže "hajmo" — **tada** se kodira
- **Ne ulepšavati procene.** Ako nešto nije izvodljivo ili traje dugo — reći jasno. Mimi smeta povlađivanje AI-a
- Radi sama, bez tima. Planira da prvi zaposleni bude **čovek za odnose sa klijentima** (kad bude resursa)

---

## TRENUTNO TEHNIČKO STANJE

### Infrastruktura
| Servis | URL / Info |
|---|---|
| Supabase | `https://vxjrctfjezzmgcrbhvwb.supabase.co` |
| Vercel | `https://cash-rheo.vercel.app` |
| GitHub | `github.com/Mima2007/cash_rheo` (public) |
| Dev env dosad | Firebase Studio (firebase.studio) |
| Novi dev env | **Claude Code (lokalno)** |
| Package name | `com.cashrheo.app` |
| Google OAuth Client ID | `865665128103-m4fgioabvr6hkst4iu5h1q3ctqrq5a55.apps.googleusercontent.com` |
| SHA-1 debug | `63:C4:80:D8:EF:A2:A0:9C:B2:B1:47:4F:FB:61:92:31:7C:07:1A:01` |

### Tech stack
- **Flutter** (pure, ne FlutterFlow)
- **Supabase** — auth, PostgreSQL, Storage
- **Vercel** — PDF generisanje (Node.js endpoint `api/generate-pdf.js`)
- **Gemini** (gemini-2.5-flash) — za AI prepoznavanje dokumenata (plan)
- **Google ML Kit** (via cunning_document_scanner, lokalni fork) — document skener

### Dizajn
- Grafit: `0xFF1C1C1E`
- Mint: `0xFF6FDDCE`
- Srebrno: `0xFFB0B0B0`

### Bitne Flutter zavisnosti (pubspec.yaml)
```
cunning_document_scanner: path: packages/cunning_document_scanner  (LOKALNI FORK!)
mobile_scanner: ^7.2.0
image_picker: ^1.2.1
image: ^4.8.0
pdf: ^3.12.0
qr_flutter: ^4.1.0
http: ^1.6.0
supabase_flutter: ^2.12.2
go_router: ^17.1.0
google_fonts: ^8.0.2
google_sign_in: ^6.3.0  (NE v7 — v7 ima drugačiji API)
shared_preferences
share_plus
path_provider
url_launcher
```

---

## ŠTA JE URAĐENO DOSAD (B2C KOMPLETNO)

### Autentifikacija
- ✅ Google Sign-In (B2C) — čuva email lokalno u SharedPreferences
- ✅ Email/password (B2B) — preko Supabase
- ✅ App prepoznaje B2C vs B2B u `lib/main.dart`

### QR skeniranje
- ✅ `mobile_scanner` radi
- ✅ Poziva suf.purs.gov.rs API za fiskalne podatke
- ✅ B2C → share PDF na mail (share_plus)
- ✅ B2B → upload na Supabase

### Dokument skeniranje
- ✅ `cunning_document_scanner` (lokalni fork) sa `SCANNER_MODE_BASE_WITH_FILTER`
- ✅ B2C → share PDF na mail
- ✅ B2B → upload na Supabase (document_service.dart uploadDirect)

### PDF generisanje (Vercel)
- ✅ NotoSansMono.ttf za ćirilicu (u `api/fonts/`)
- ✅ Font radi — test: `curl -X POST https://cash-rheo.vercel.app/api/generate-pdf -d '{"journal":"ТЕСТ","qrUrl":""}'` vraća HTTP 200

### UI polish
- ✅ Početna strana: "SKENIRAJ QR" (sa subtitle "Fiskalni racun") + "USLIKAJ" (bez subtitle-a)
- ✅ Poruka posle slanja: "Poslato" (B2C) umesto "Pripremljeno za slanje!"

---

## BITNE ODLUKE I DEBATE IZ PRETHODNIH SESIJA

### Kvalitet skeniranja dokumenata

**Testirali smo 3 SCANNER_MODE opcije u Google ML Kit:**
- SCANNER_MODE_FULL: agresivan crno-beli filter, tekst "izgrizen"
- SCANNER_MODE_BASE: sirova fotografija, senke vidljive
- **SCANNER_MODE_BASE_WITH_FILTER** (izabrano): najbolji balans, ALI korisnik mora ručno da klikne Filter → Auto da bi dobio čistu belu pozadinu. Default je "Original".

**Pokušaj automatskog filtera u Dart kodu:** Napravili smo `_enhanceDocument()` metodu u `document_service.dart` (brightness 1.15, contrast 1.25, saturation 0.7). **Rezultat je bio presvetljen, tekst opran.** Vraćeno na original. Metoda `_enhanceDocument` ostaje u fajlu kao neiskorišćena.

**Istraženo (ne radimo sad, u mentalnom katalogu):**
- Scanbot SDK, Docutain SDK — komercijalni, CamScanner nivo, skupi (€2,000-15,000 godišnje, cena nije javna)
- OpenCV custom pipeline — 2-3 meseca rada, može dostići 80-90% CamScanner-a uz AI pomoć
- Flutter nema "ubaci i radi" paket koji daje CamScanner kvalitet
- Google ML Kit ima otvoren bug (GitHub #769/#935) za low quality od aprila 2025, godinu dana nerešen
- iOS VisionKit (preko istog `cunning_document_scanner` paketa) daje bolji rezultat automatski na iPhone-u

**Trenutna odluka:** Ostavljamo BASE_WITH_FILTER, idemo na Play Store. Kvalitet skenera rešavamo posle, bez tenzije, kad bude prvih korisnika i feedback-a.

### Odbačene opcije
- **Gemini da prečita dokument pa generiše čist PDF:** Odbačeno jer nestaju pečati, QR kodovi, i može biti halucinacija brojeva (katastrofalno za poresku)
- **Automatski filter na backend-u (Supabase + Vercel OpenCV):** Odbačeno za sada, nema garancije boljeg kvaliteta

---

## BASH GOTCHA (VAŽNO ZNATI)

U prethodnim sesijama smo gubili vreme jer:

**`sed -i "..."` sa duplim navodnicima i `!` u tekstu NE RADI** — bash history expansion interpretira `!` kao istorijsku komandu i komanda tiho padne sa porukom `bash: !: event not found`.

**Uvek koristiti:**
- `sed -i '...'` (single quotes) — kad tekst ima `!`
- `sed -i $'...'` (C-style string) — alternativa ako moraš single quotes unutra

Ovo nam je **tri puta** napravilo problem pre nego što smo primetili.

---

## KLJUČNI FAJLOVI (trenutno stanje)

```
cash_rheo/
├── lib/
│   ├── main.dart                           # Router, B2C/B2B detekcija
│   ├── services/
│   │   ├── auth_service.dart               # Google login, isB2C, userEmail
│   │   ├── pdf_service.dart                # generateAndUpload (B2B) + shareViaMail (B2C)
│   │   ├── receipt_service.dart            # Supabase fiskali (B2B)
│   │   └── document_service.dart           # uploadDirect (B2B) + shareViaMail (B2C) + _enhanceDocument (NEISKORIŠĆENA)
│   └── pages/
│       ├── home_page.dart                  # SKENIRAJ QR + USLIKAJ dugmad
│       ├── login_page.dart                 # Google dugme + email/password
│       ├── register_page.dart              # B2B registracija
│       ├── qr_scan_page.dart               # QR skener, B2C share / B2B Supabase
│       └── document_scan_page.dart         # Document skener, B2C share / B2B Supabase
├── api/
│   ├── generate-pdf.js                     # Vercel PDF endpoint (ćirilica radi)
│   └── fonts/NotoSansMono.ttf              # Variable font za ćirilicu
├── packages/
│   └── cunning_document_scanner/           # LOKALNI FORK sa SCANNER_MODE_BASE_WITH_FILTER
├── pubspec.yaml
└── .idx/dev.nix                             # Firebase Studio konfiguracija (Java 17)
```

---

## SLEDEĆI KORACI (prioritizovano)

### KORAK 1 — Finalna provera Google ML Kit skenera (ODMAH)
Uslikati 3-4 različita dokumenta (fiskal, ugovor/otpremnica, možda neki stari papir sa nabocima) da potvrdimo da:
- Edge detection radi
- Perspective correction radi
- Filter → Auto daje prihvatljiv kvalitet za sve tipove
- PDF se pošalje na mail bez greške

Ako sve radi → idemo na Korak 2.
Ako ima bugova → rešavamo ih pre Play Store-a.

### KORAK 2 — Release keystore (KRITIČNO)
Generisati production signing key. **Ne može se promeniti posle!** Čuvati na više mesta (password manager, USB, cloud backup).

Komanda (sa sigurnim parametrima):
```bash
keytool -genkey -v -keystore ~/cash_rheo_release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias cash_rheo
```

Konfigurisati `android/key.properties` i `android/app/build.gradle.kts` za release potpisivanje.

### KORAK 3 — App Bundle (.aab)
Umesto APK-a, za Play Store treba App Bundle:
```bash
flutter build appbundle --release
```
Izlaz: `build/app/outputs/bundle/release/app-release.aab`

### KORAK 4 — Google Play Developer nalog
- $25 jednokratno
- Registracija, verifikacija identiteta, bankovni podaci
- 1-3 dana verifikacije

### KORAK 5 — Store listing
- App ikonica 512x512 PNG (trenutno default Flutter — treba dizajn)
- Feature graphic 1024x500
- Minimum 2 screenshot-a (preporučeno 4-8)
- Kratak opis (80 karaktera)
- Dug opis (4000 karaktera)
- **Privacy Policy URL** (OBAVEZNO za Google login)
- Kategorizacija (Produktivnost / Finansije / Biznis)

### KORAK 6 — Internal testing
Pre pravog release-a, testiraj sa 5-10 ljudi preko "Internal testing" track-a.

### KORAK 7 — Production release
Submit na review. Google obično odobrava za 1-3 dana za prve app-ove (može i duže).

### KASNIJE (ne sada)
- B2B finalizacija (QR pozivnica za firmu, OTP vozači, kamion potvrda, dashboard)
- Reklame (interstitial 5 sec)
- In-app purchase za Pro verziju
- Skener kvalitet poboljšanje (kroz OpenCV ili komercijalni SDK, kad bude feedback-a)
- iOS verzija (automatski dobija VisionKit = bolji skener)

---

## KAKO DA CLAUDE CODE RADI SA MIMOM

**Komunikacioni stil:**
- Piše na srpskom
- Ne povlađuje, ne ulepšava procene
- Razlikuje "razgovaramo" od "kodiramo"
- Daje iskrene procene vremena i rizika
- Kratki, konkretni odgovori kad kodira; detaljna objašnjenja kad se istražuje

**Šta Mima očekuje:**
- Pre većih izmena — sažetak plana
- Komande jedna po jedna ili u logičnim blokovima
- Provere posle svake izmene (grep, test)
- Commit na git kad završimo logičku celinu

**Šta izbegavati:**
- Ne gurati ka implementaciji ako pita "šta misliš o X"
- Ne obećavati "top rešenje" za stvari koje nisu proverene
- Ne praviti duge `sed` komande sa `!` u duplim navodnicima

---

## INSTRUKCIJA ZA CLAUDE CODE

Kada Mima pokrene prvu sesiju u Claude Code-u, čitaj ovaj sažetak i **počni sa Korak 1** — predloži da uslika nekoliko test dokumenata pa da analiziramo rezultat zajedno. Ne kreći direktno na keystore dok ne potvrdimo da je skener OK.

Pre bilo koje izmene u kodu, pitaj Mimu da potvrdi plan. Ona je vlasnik odluka — ti si tehnički partner.
