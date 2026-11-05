# Afrikaans / isiXhosa glossary for the demo UI

This glossary was used by the AI translation agents that produced
`config/locales/decidim/af/*.yml` and `config/locales/decidim/xh/*.yml`
(plan U3). The translations are **machine-translated and have not been reviewed
by a first-language speaker**. The Afrikaans should be usable. The isiXhosa is
best effort. Neither is suitable for production without review.

## 1. Official City of Cape Town terms

These come from trilingual City documents. See
`docs/research/2026-11-05-cct-public-participation-sources.md` §6 for sources
and caveats. Use them exactly.

| English | Afrikaans | isiXhosa |
|---|---|---|
| ward / wards | wyk / wyke | iwadi / iiwadi |
| ward number | wyksnommer | inombolo yewadi |
| ward councillor | wyksraadslid | uceba wewadi (not verified) |
| subcouncil / subcouncils | subraad / subrade | iBhungana / amaBhungana |
| Council | (die) Raad | iBhunga |
| City of Cape Town | Stad Kaapstad | iSixeko saseKapa |
| by-law | verordening | umthetho kamasipala |
| budget | begroting | uhlahlo-lwabiwo-mali |
| Integrated Development Plan (IDP) | geïntegreerde ontwikkelingsplan (GOP/IDP) | iSicwangciso soPhuhliso esiHlanganeneyo (IDP) |
| ward allocation | wykstoewysing | isabelo sewadi / izabelo zewadi |
| annexure | bylae | isihlomelo |
| public participation | openbare deelname (not verified) | ukuthatha inxaxheba koluntu (not verified) |
| ward committee | wykskomitee (not verified) | ikomiti yewadi (not verified) |

## 2. Decidim platform terms

These renderings were chosen for consistency. Use the same word everywhere in
the UI.

| English (Decidim) | Afrikaans | isiXhosa |
|---|---|---|
| participatory process | deelnemende proses (pl. deelnemende prosesse) | inkqubo yokuthatha inxaxheba (pl. iinkqubo zokuthatha inxaxheba) |
| participatory space / space | deelnameruimte / ruimte | indawo yokuthatha inxaxheba / indawo |
| assembly | forum (pl. forums) | indibano (pl. iindibano) |
| meeting | vergadering (pl. vergaderings) | intlanganiso (pl. iintlanganiso) |
| proposal | voorstel (pl. voorstelle) | isindululo (pl. izindululo) |
| amendment | wysiging | isilungiso |
| budget (Decidim budgets component) | begroting | uhlahlo-lwabiwo-mali |
| project (budget project) | projek | iprojekthi |
| vote (verb / noun) | stem / stem | vota / ivoti |
| support (a proposal) | steun | xhasa / inkxaso |
| like / endorsement | hou van / goedkeuring | thanda / ukuxhasa |
| comment | kommentaar (pl. kommentare) | isimvo (pl. izimvo) |
| debate | debat | ingxoxo |
| survey | opname | uphando |
| questionnaire / form | vraelys / vorm | uluhlu lwemibuzo / ifomu |
| result (accountability) | resultaat | isiphumo |
| accountability | aanspreeklikheid | uxanduva |
| blog / post | blog / plasing | ibhlog / umyalezo |
| page | bladsy | iphepha |
| step / phase | fase | inqanaba |
| component | komponent | icandelo |
| organization | organisasie | umbutho |
| admin / administrator | administrateur | umlawuli |
| admin dashboard | administrasiepaneel | iphaneli yolawulo |
| participant | deelnemer | umthathi-nxaxheba |
| user | gebruiker | umsebenzisi |
| user group / group | gebruikersgroep / groep | iqela labasebenzisi / iqela |
| account | rekening | iakhawunti |
| profile | profiel | iprofayile |
| nickname | bynaam | igama lesidlaliso |
| sign in / sign out / sign up | meld aan / meld af / registreer | ngena / phuma / bhalisa |
| password | wagwoord | igama lokugqitha |
| email | e-pos | i-imeyile |
| notification | kennisgewing | isaziso |
| conversation / message | gesprek / boodskap | incoko / umyalezo |
| follow / follower | volg / volger | landela / umlandeli |
| report (flag content) | rapporteer | xela |
| moderation / moderator | moderering / moderator | ukumodareyitha / umodareyitha |
| hide | versteek | fihla |
| authorization / verification | magtiging / verifikasie | ugunyaziso / uqinisekiso |
| scope | omvang | umda |
| area | area | ummandla |
| taxonomy | taksonomie | itaksonomi |
| category | kategorie | udidi |
| filter | filter | hluza / isihluzi |
| search | soek | khangela |
| attachment | aanhangsel | isincamathiselo |
| draft | konsep | uyilo |
| publish / unpublish | publiseer / depubliseer | papasha / rhoxisa ukupapasha |
| newsletter | nuusbrief | incwadana yeendaba |
| terms of service | diensbepalings | imimiselo yenkonzo |
| privacy policy | privaatheidsbeleid | umgaqo-nkqubo wobumfihlo |
| home | tuis | ekhaya |
| help | hulp | uncedo |
| save / cancel / edit / delete | stoor / kanselleer / wysig / skrap | gcina / rhoxisa / hlela / cima |
| create / update / back / next / close | skep / opdateer / terug / volgende / maak toe | yila / hlaziya / buyela umva / okulandelayo / vala |
| export / import | voer uit / voer in | thumela ngaphandle / ngenisa |

## 3. Style rules

- **Afrikaans:** use the informal but polite second person (`jy` / `jou`)
  throughout. Use sentence case for labels, like the English source.
- **isiXhosa:** use standard written isiXhosa (second person `u-` / `wakho`).
  Keep English technical words where no common isiXhosa word exists. Prefer
  clarity over purity.
- Never translate: `Decidim`, product or brand names, URLs, email addresses,
  `%{...}` and `%<...>s` placeholders, strftime formats (`%d %b %Y`), HTML tags
  and attributes, Markdown syntax, or i18n key references.
