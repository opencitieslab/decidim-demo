# City of Cape Town public participation: seed sources for the Decidim demo

Researched 2026-11-05. Machine-readable companion: [`cct-seed-sources.json`](cct-seed-sources.json).
Scope: official CCT sources were preferred, with reputable SA news used to corroborate them. No personal data was collected. Councillor and official names are deliberately left out. All summaries are paraphrased.

> **Headline corrections to the brief**
> - **Subcouncils: 20, not 24.** The City went from 24 to 21 in 2022, then to 20 under the Sub-council Amendment By-law of 30 Aug 2024 (Provincial Gazette 8974).
> - **Wards: 116 → 118 (likely).** The 2021 delimitation had 116 wards. The **local government election was held on 4 Nov 2026**, yesterday relative to this research, and the 2026 ward boundaries take effect after it. The CCT Open Data Portal "Wards" layer now holds **118 wards (WARD_YEAR 2026)**. The press has confirmed only the new **Ward 117** (Parklands/West Beach). Ward 118 is visible in the dataset only.
> - **CCT already runs a digital participation platform:** **Go Vocal** (formerly CitizenLab) at `capetown.govocal.com`, linked from capetown.gov.za/haveyoursay. Its public JSON API (`/web_api/v1/projects`, `/areas`, `/global_topics`) supplied most of the dates in section 2. The platform is **en-GB only**, so a trilingual (en/af/xh) Decidim demo stands out.

---

## 1. Governance structure

### 1.1 Counts

| Fact | Value | Source |
|---|---|---|
| Subcouncils | 20 (since by-law of 30 Aug 2024; previously 21 from 2022, and 24 before that) | [CCT subcouncils page](https://www.capetown.gov.za/Family%20and%20home/Meet-the-City/City-Council/subcouncils) · [Sub-council By-law (consolidated, 2024-08-30)](https://openbylaws.org.za/akn/za-cpt/act/by-law/2003/sub-council/eng@2024-08-30) · [Amendment By-law 2024 PDF (trilingual)](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Bylaws%20and%20policies/Sub-Council_Amendment_By-law_2024.pdf) |
| Wards (2021–2026 council term) | 116 | [CCT wards page](https://www.capetown.gov.za/Family%20and%20home/Meet-the-City/city-council/wards) · [CCT media release, Dec 2021](https://www.capetown.gov.za/Media-and-news/Proposals%20to%20amend%20the%20Subcouncil%20boundaries) |
| Wards (2026 delimitation, effective after 4 Nov 2026 election) | **118 in ODP layer** (uncertain). Press confirms new Ward 117 | [ODP Wards FeatureServer](https://esapqa.capetown.gov.za/agsext/rest/services/Theme_Based/ODP_SPLIT_5/FeatureServer/6) · [Tygerburger, 1 Jun 2026](https://novanews.co.za/tygerburger/?p=322387) |
| Election date | Wed 4 Nov 2026 (proclaimed 7 Aug 2026) | [EWN](https://www.ewn.co.za/2026/08/07/minister-hlabisa-proclaims-4-november-as-local-government-election-date) |
| Subcouncil meetings | At least monthly except during recess. Open to the public | [By-law s9](https://openbylaws.org.za/akn/za-cpt/act/by-law/2003/sub-council/eng@2024-08-30) · [Attend a subcouncil meeting](https://www.capetown.gov.za/City-Connect/Get-involved/attend/attend-a-subcouncil-meeting) |

### 1.2 Subcouncil → wards → areas → office (venue)

Wards come from **Schedule 2** of the by-law as amended in 2024, which follows the 2021 delimitation. My parse confirms all 116 wards are covered exactly once. Area labels are the City's own labels from its Go Vocal platform ([areas API](https://capetown.govocal.com/web_api/v1/areas)), abridged here. Office addresses come from the City's [2025/26 Budget "Have Your Say" venues list](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Forms,%20notices,%20tariffs%20and%20lists/HYS_2025-26Budget_Venues_List.pdf). No 2026/27 list was found.

| # | Wards (2021 delimitation) | Areas (City label, abridged) | Office address / meeting venue |
|---|---|---|---|
| 1 | 23, 29, 32, 107 (+117 from 2026, inferred) | Atlantis, Mamre, Melkbosstrand, Bloubergstrand, Table View, Parklands, West Beach, Big Bay | Municipal Offices, cnr Grosvenor & Hermes Ave, Saxonsea, Atlantis |
| 2 | 6, 7, 8, 101, 102, 111 | Brackenfell, Kraaifontein, Scottsdene, Wallacedene, Haasendal | Municipal Offices, 87 Brighton Way, Kraaifontein |
| 3 | 4, 55, 56, 104, 113 | Milnerton, Dunoon, Edgemead, Montague Gardens, Century City, Joe Slovo Park, Kensington/Maitland | Milnerton Municipal Building, 1st Floor, Royal Ascot, Bridle Way, Milnerton |
| 4 | 25, 26, 27, 28 | Bishop Lavis, Elsies River, Goodwood, Parow Valley, Ruyterwacht, Ravensmead, Uitsig | Municipal Offices, cnr Voortrekker & Tallent Rds, Parow |
| 5 | 12, 13, 20, 22, 24, 106 | Belhar, Bellville, Kuils River, Delft, The Hague, Voorbrug | Municipal Offices, cnr Jakkelsvlei Ave & Kiaat Rd, Bonteheuwel |
| 6 | 2, 3, 9, 10 | Bellville CBD, Parow, Boston, Oakdale, Bellville South | Municipal Offices, Voortrekker Road, Bellville |
| 7 | 1, 5, 21, 70, 103, 105, 112 | Durbanville, Fisantekraal, Bothasig, Welgemoed, Panorama | Municipal Offices, Oxford Street, Durbanville |
| 8 | 15, 83, 84, 85, 86, 100, 109 | Somerset West, Strand, Gordon's Bay, Macassar, Sir Lowry's Pass, Nomzamo, Lwandle | Municipal Offices, cnr Fagan St & Main Rd, Strand |
| 9 | 18, 87, 89, 90, 91, 93 | Blue Downs, Mfuleni, Driftsands, Khayelitsha (Victoria Mxenge, Nonqubela, Thembokwezi) | Site B, cnr Bonga & Sulani Dr, Khayelitsha Shopping Centre |
| 10 | 94, 95, 96, 97, 98, 99 | Khayelitsha (Kuyasa, Harare, Ilitha Park, Monwabisi) | Khayelitsha Training Centre, cnr Lwandle & Phendula Cres |
| 11 | 30, 44, 46, 47, 48, 49, 60 | Athlone, Bridgetown, Manenberg, Heideveld, Rylands, Gatesville, Lansdowne | Dulcie September Civic Centre, cnr Protea & Klipfontein Rd, Kewtown, Athlone |
| 12 | 35, 76, 82, 92, 116 | Mitchells Plain east (Beacon Valley, Eastridge, Lentegeur, Tafelsig) | Lentegeur Admin Building, cnr Melkbos & Merrydale Rds, Lentegeur |
| 13 | 34, 36, 37, 38, 39, 40, 41, 80 | Crossroads, Gugulethu, Nyanga | Fezeka Building, cnr Steve Biko Dr & Lansdowne Rd, Gugulethu |
| 14 | 11, 14, 16, 17, 19, 108, 114 (+118 from 2026, inferred) | Blackheath, Blue Downs, Eerste River, Kleinvlei, Kuils River | Fezeka Building, Gugulethu *(as published, which looks odd for this area, so verify)* |
| 15 | 31, 42, 50, 51, 52 | Langa, Pinelands, Kensington, Maitland | Pinelands Training Centre, St Stephens Rd, Central Square, Pinelands |
| 16 | 53, 54, 57, 77, 115 | CBD, Bo-Kaap, Gardens, Sea Point, Green Point, Camps Bay, Woodstock, Observatory | 11th Floor, 44 Wale Street, Cape Town |
| 17 | 33, 43, 75, 78, 79, 81, 88 | Philippi, Mitchells Plain (Rocklands, Westridge), Strandfontein | Lentegeur Admin Building, Lentegeur *(as published)* |
| 18 | 65, 66, 67, 68, 72, 110 | Grassy Park, Retreat, Ottery, Plumstead, Lotus River | cnr Buck Road & 6th Avenue, Lotus River |
| 19 | 45, 61, 64, 69 | Muizenberg, Fish Hoek, Kalk Bay, Simon's Town, Kommetjie, Noordhoek, Ocean View | Municipal Offices, Central Circle, off Recreation Rd, Fish Hoek |
| 20 | 58, 59, 62, 63, 71, 73, 74 | Claremont, Rondebosch, Newlands, Wynberg, Constantia, Tokai, Hout Bay, Kenilworth | Alphen Centre, Main Road, Constantia |

Other official venues on the same list are the **Civic Centre Concourse, Hertzog Boulevard, Cape Town**, **Plumstead Municipal Offices (cnr Main & Victoria Rds)** and all City libraries.

**Caveat:** Wards 117 and 118 are not yet in any by-law schedule. I assigned them to subcouncils by testing each ward centroid against the ODP Subcouncils polygon layer: 117 falls in SC1, and 118 falls in SC14 within the "Driftsands" planning suburb. A post-election by-law amendment, and possible renumbering, should be expected.

### 1.3 Spatial datasets (CCT Open Data Portal, ArcGIS Hub)

| Dataset | Endpoint | Notes |
|---|---|---|
| Wards (2000–2026 vintages; live layer = 2026, 118 features) | [FeatureServer/6](https://esapqa.capetown.gov.za/agsext/rest/services/Theme_Based/ODP_SPLIT_5/FeatureServer/6) · [item page](https://odp-cctegis.opendata.arcgis.com/datasets/358f42b351c2451f89e2b38dd6f2668f) | Fields: `WARD_NAME`, `WARD_YEAR`. **GeoJSON export verified:** `…/FeatureServer/6/query?where=1%3D1&outFields=*&outSR=4326&f=geojson` |
| Subcouncils (as at Sept 2024) | [FeatureServer/5](https://esapqa.capetown.gov.za/agsext/rest/services/Theme_Based/ODP_SPLIT_5/FeatureServer/5) | Fields: `SUB_CNCL_NAME`, `SUB_CNCL_NMBR` |
| Official Planning Suburbs | [FeatureServer/3](https://esapqa.capetown.gov.za/agsext/rest/services/Theme_Based/ODP_SPLIT_5/FeatureServer/3) | Field: `OFC_SBRB_NAME`. Spatially join it with wards to get ward→suburb lists |
| Licence | [Open Data terms of use](https://www.capetown.gov.za/General/Terms-of-use-open-data) | Data is supplied "without any remuneration" under the City's Open Data Policy (2020), "as is", with no warranty. **No named open licence (e.g. CC-BY) was found**, so attribute "City of Cape Town Open Data Portal" and treat redistribution terms as uncertain. |

**Ward-to-suburb lists:** no official flat list was found. Use the Go Vocal subcouncil area labels above, or do a spatial join of the Wards and Official Planning Suburbs layers.

---

## 2. Real public participation items (2025–2026)

Dates come from the phase start/end on the City's Go Vocal platform unless noted otherwise. "Status" is as of 2026-11-05. Theme keys refer to section 5. Departments marked "(uncertain)" were inferred from the content.

| # | Title | Summary (paraphrased) | Open → Close | Dept | Area | Theme | Status | Source |
|---|---|---|---|---|---|---|---|---|
| 1 | Comment on the City's draft Budget 2026-2027 | The "City of Hope" draft was tabled 31 Mar 2026 around a three-year R40bn infrastructure programme, with water & sanitation the largest share. Comments were taken online, by email, by phone or at subcouncil offices. IDP review amendments were advertised with it. | 2026-04-01 → 2026-04-30 | Finance | City-wide | capable_government | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/draft-budget-2026-2027) · [CCT release](https://www.capetown.gov.za/Media-and-news/Cape%20Town%20tables%20R40%20billion%20basic%20infrastructure%20budget%20to%20improve%20services%20to%20all) |
| 2 | Comment on Amendments to 2026/27 March Tabled Budget | The High Court set aside the property-value-linked fixed water, sanitation and cleaning charges. The City then reopened comment on tariff amendments only: meter-size fixed charges, cleaning moved back into rates, higher step tariffs above 10.5kl, and wider rates relief. | 2026-05-27 → 2026-06-10 | Finance | City-wide | basic_services | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-city-s-amended-draft-budget-for-2026-2027) · [EWN](https://www.ewn.co.za/2026/05/22/cape-town-amends-budget-after-high-court-rules-tariff-model-unlawful) |
| 3 | 2025/26 mid-year adjustments to the 2022-27 IDP | Mid-year changes to IDP scorecard indicators and targets. | 2026-02-06 → 2026-03-27 | IDP office (uncertain) | City-wide | capable_government | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-2025-26-mid-year-adjustments-to-the-2022-27-integrated-development-plan-idp) |
| 4 | Process for the New Term of Office IDP 2027–2032 | Sets out how the new council's five-year IDP will be drafted. The approved schedule has community inputs from Nov 2026, a draft IDP out for comment Feb–Apr 2027, and adoption with the 2027/28 budget. | 2026-09-25 → 2026-10-25 | IDP office (uncertain) | City-wide | capable_government | closed; drafting next | [Go Vocal](https://capetown.govocal.com/en-GB/projects/intention-to-submit-a-process-outlining-the-drafting-of-the-new-term-of-office-integrated-development-plan-idp-2027-2032-amendment-to-council) · [IDP & Budget time-schedule 2026/27](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/City%20strategies,%20plans%20and%20frameworks/IDP-and-Budget-Time-Schedule_2026-27.pdf) |
| 5 | Draft Short-Term Letting By-law | Would require a City registration number on short-term rental listings and data-sharing by booking platforms. It would also build the evidence base for rating heavily let homes as commercial (reported threshold >50% of room-nights, from Jul 2027). | 2026-08-05 → 2026-10-05 | Finance / rates (uncertain) | City-wide | spatial_integration | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/draft-short-term-letting-by-law) · [CCT release](https://www.capetown.gov.za/Media-and-news/Short-Term%20Letting%20By-Law%20open%20for%20public%20comment) |
| 6 | Draft Animal Keeping By-law, 2026 | Revises the 2021 by-law on pet-owner duties, beekeeping, nuisances, impoundment, dog identification and leashing outside off-leash zones. It was hotly debated, and the City said no pet licensing was planned. | 2026-08-28 → 2026-09-29 | Safety & Security (Law Enforcement) | City-wide | safety | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/template-public-participation-campaign-copy-1) · [CCT release](https://web1.capetown.gov.za/web1/newsandnotices/Home/Release/Comment-on-the-City-s-draft-Animal-Keeping-By-law) |
| 7 | Amendments to the Municipal Planning By-law, 2015 | Changes to the by-law that governs land-use and development applications. | 2026-07-03 → 2026-07-22 | Spatial Planning & Environment | City-wide | spatial_integration | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/proposed-amendments-to-the-city-of-cape-town-municipal-planning-by-law-2015) |
| 8 | Comprehensive Integrated Transport Plan 2026 update | The second annual update to CITP 2023–28, reportedly folding in the IPTN 2040 rail projects. Comments were accepted by email or at libraries, subcouncils and the Civic Centre. | 2026-09-01 → 2026-09-30 | Urban Mobility | City-wide | transport | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-comprehensive-integrated-transport-plan-2026-update) · [Cape Chamber](https://capechamber.co.za/latest-news/public-comment-opens-cape-towns-2026-transport-plan-update) |
| 9 | Draft Road Safety Strategy | Prioritises pedestrians, cyclists, scholars and public transport users, informed by a 2023 call for ideas that drew 3,000+ comments. Council approved it in Aug 2026. | 2026-05-08 → 2026-06-08 | Urban Mobility | City-wide | transport | closed; adopted | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-of-the-draft-road-safety-strategy-rss) · [CCT release](https://web1.capetown.gov.za/web1/newsandnotices/Home/Release/City-Council-approves-Road-Safety-Strategy-for-Cape-Town) |
| 10 | Draft CTMPD Police Plan 2026/27 | The Metro Police annual policing plan, put out for comment. | 2026-05-25 → 2026-06-29 | Safety & Security | City-wide | safety | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/draft-ctmpd-police-plan-2026-2027) |
| 11 | Draft Heritage Resources Management Strategy | Revises the 2005 strategy to embed heritage in planning, align it with sustainability and cut red tape. Summaries were published in en/af/xh, and a virtual info session ran on 27 Aug 2026. | 2026-08-17 → 2026-09-17 | Spatial Planning & Environment | City-wide | public_space_environment | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-draft-heritage-resource-management-strategy-for-the-city-of-cape-town) · [CCT release](https://web1.capetown.gov.za/web1/newsandnotices/Home/Release/Comment-on-the-City-s-draft-Heritage-Resources-Management-Strategy) |
| 12 | Kensington/Factreton/Wingfield LSDF | A local spatial plan along the Voortrekker Road Corridor responding to informal settlement growth, congestion and infrastructure strain. | 2026-09-01 → 2026-11-01 | Spatial Planning & Environment | SC3 | spatial_integration | just closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-local-spatial-development-framework-lsdf-for-kensington-factreton-wingfield-area) · [CCT release](https://www.capetown.gov.za/Media-and-news/Call%20on%20residents%20to%20help%20craft%20a%20spatial%20vision%20for%20Kensington%20and%20Factreton%20areas) |
| 13 | Draft Big Bay LSDF | A local spatial framework for the fast-growing Big Bay/Blouberg area. | 2025-10-03 → 2025-12-13 | Spatial Planning & Environment | SC1, SC3 | spatial_integration | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-draft-big-bay-local-spatial-development-framework-lsdf) |
| 14 | Review of Draft Combined Rules for Ward Committees | Rules for electing and running ward committees, to be re-established after the election. Civil society asked for co-drafting rather than a 30-day comment period. | 2026-10-01 → 2026-10-31 | Public Participation (uncertain) | All wards | capable_government | just closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/Comment-on-The-Review-of-the-Draft-combined-rules-for-Ward-Commitees) · [allAfrica/GroundUp](https://allafrica.com/stories/202605050100.html) |
| 15 | Proposed Informal Trading Plan for Thembokwezi Market | Trading bays and rules for Thembokwezi Market in Khayelitsha. It follows a March 2026 draft. | 2026-10-29 → 2026-11-29 | Economic Growth | SC9 (Khayelitsha) | economic_growth | **OPEN** | [Go Vocal](https://capetown.govocal.com/en-GB/projects/proposed-informal-trading-plan-for-thembokwezi-market) |
| 16 | Proposed closure of lanes/walkways, Ward 12 Belhar | A notice proposing to close specific pedestrian lanes in Belhar. | 2026-11-02 → 2026-12-02 | (uncertain) | Ward 12, SC5 | safety | **OPEN** | [Go Vocal](https://capetown.govocal.com/en-GB/projects/proposed-closure-of-lanes-walkaways-in-ward-12-belhar) |
| 17 | Bo-Kaap Bin Survey & Waste Management Education | A household survey on bins and collection, combined with education. | 2026-10-08 → 2026-10-28 | Urban Waste Management | SC16 (Bo-Kaap) | basic_services | closed (survey) | [Go Vocal](https://capetown.govocal.com/en-GB/projects/bo-kaap-bin-survey-and-waste-management-education) |
| 18 | Temporary MyCiTi bus stops in Wynberg | Temporary stops linked to MyCiTi Phase 2A works. | 2026-02-27 → 2026-03-31 | Urban Mobility | SC20 (Wynberg) | transport | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-proposed-temporary-myciti-bus-stops-in-wynberg) · [MyCiTi Phase 2A](https://myciti.org.za/en/phase2a) |
| 19 | Draft contract: water reuse projects | A statutory contract notice for water-reuse schemes under the New Water Programme. | 2026-02-13 → 2026-02-24 | Water & Sanitation | City-wide | resilience | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-draft-contract-relating-to-water-reuse-projects) |
| 20 | Contract amendment: managed aquifer recharge plant, Cape Flats WWTW | A plant that treats water to recharge the Cape Flats Aquifer. | 2026-10-30 → 2026-11-09 | Water & Sanitation | Cape Flats | resilience | **OPEN** | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-amendment-of-an-existing-contract-relating-to-the-new-managed-aquifer-recharge-water-treatment-plant-at-the-cape-flats-wastewater-treatment-works) |
| 21 | Draft Burial, Cremation and Cemeteries Management Policy | A new policy for cemetery and crematorium management. | 2026-08-18 → 2026-10-05 | Community Services & Health | City-wide | public_space_environment | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-draft-burial-cremation-and-cemeteries-management-policy) |
| 22 | Lease of City-owned properties for shelters | Leasing several City sites to organisations that run shelters for street people. | 2026-02-02 → 2026-03-03 | (uncertain) | Multiple | housing | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-proposed-lease-of-various-city-owned-properties-for-shelter-purposes) |
| 23 | Call for business plans: ECD centre in Bosasa (Ward 114) | A call for an operator for a City-built early childhood development centre. | 2026-05-18 → 2026-06-18 | Community Services & Health | Ward 114, SC14 | public_space_environment | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/call-for-submission-of-business-plans-operation-of-an-early-childhood-development-ecd-centre-in-bosasa-ward-114) |
| 24 | Proposed vision for Rondebosch CBD Main Road | A proposed urban-design vision for the Rondebosch high street. | 2026-05-28 → 2026-06-25 | (uncertain) | Rondebosch (SC20) | spatial_integration | closed | [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-proposed-vision-for-rondebosch-cbd-main-road) |
| 25 | Resident Ideas (always-open ideas board) | The City's continuous ideas board, with 177 ideas at time of research. It is the closest analogue to Decidim Proposals. | 2025-07-01 → ongoing | City-wide | City-wide | capable_government | **OPEN** | [Go Vocal](https://capetown.govocal.com/en-GB/projects/resident-ideas) |

**Programme context for themes with no current comment window.** These are good as process descriptions or budget lines rather than consultations:
- **MyCiTi Phase 2A (Metro South-East: Mitchells Plain, Khayelitsha, Wynberg, Claremont).** The draft budget has R3.3bn for the Cape Flats expansion. Red bus lanes are going in on Govan Mbeki Rd (May–Dec 2026), and Hanover Park/Mitchells Plain stations start in Sept 2026. The service start is reported as July 2027, with funding risk because the national PTNG grant is ending. Sources: [CCT release](https://www.capetown.gov.za/Media-and-news/Cape%20Town%20tables%20R40%20billion%20basic%20infrastructure%20budget%20to%20improve%20services%20to%20all), [MyCiTi Phase 2A newsletter Mar 2026](https://www.myciti.org.za/userdocs/Phase%202A%20Newsletter%20-%20March%202026.pdf), [BusinessDay, Oct 2026](https://www.businessday.co.za/news/2026-10-16-doubts-over-the-future-of-myciti-buses-as-treasury-ends-grant/).
- **LEAP (Law Enforcement Advancement Plan).** The programme is jointly funded by the Province and the City, with roughly 1,200 officers deployed by crime analysis to hotspots such as Khayelitsha, Philippi East, Nyanga, Gugulethu, Delft and Mitchells Plain. No 2026 LEAP-specific budget was found. Sources: [WCG LEAP page](https://www.westerncape.gov.za/law-enforcement-advancement-plan-leap), [EWN 2024](https://www.ewn.co.za/2024/09/17/more-leap-officers-to-be-deployed-to-violence-hit-cape-town-communities).
- **Informal settlements.** The City's Feb 2026 database lists 646 informal settlements with just over 1 million residents. The draft budget puts R3.3bn into informal settlement upgrading plus subsidised housing. Sources: [PMG question NW57](https://pmg.org.za/committee-question/35860/), [CCT release](https://www.capetown.gov.za/Media-and-news/Cape%20Town%20tables%20R40%20billion%20basic%20infrastructure%20budget%20to%20improve%20services%20to%20all).
- **Energy / load-shedding.** The draft budget has R6bn over three years for grid upgrades, and the energy budget was marketed as an "Energy Independence Plan". The last formal Energy Strategy consultation was in 2023. **No 2025–26 "Integrated Resource Plan" comment process was found.** Sources: [CCT, R1.2bn energy security](https://www.capetown.gov.za/Media-and-news/City%20commits%20more%20than%20R1,2%20billion%20on%20energy%20security,%20diversification), [CCT Energy Strategy 2023](https://www.capetown.gov.za/Media-and-news/Cape%20Town's%20Energy%20Strategy%20out%20for%20public%20comment).
- **Mayoral Urban Regeneration Programme (MURP).** This is a precinct-based programme for CBDs, town centres, transport interchanges and corridors. No authoritative 2026 precinct list or budget line was found. Source: [CCT budget release, Apr 2026](https://www.capetown.gov.za/Media-and-news/Budget%20prioritises%20healthy%20vleis,%20a%20resilient%20coastline,%20biodiversity,%20urban%20regeneration,%20and%20economic%20growth).
- **Subcouncil boundary review.** The 2024 change (21→20) had its own comment window, 9–31 Jul 2024. Source: [Go Vocal](https://capetown.govocal.com/en-GB/projects/comment-on-the-proposed-new-subcouncil-boundaries).

---

## 3. Budget figures and ward allocations (for a Budgets component)

| Figure (2026/27) | Value | Source |
|---|---|---|
| Adopted | 29 Jun 2026, special Council meeting | [Covering report](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Financial%20documents/Budget-2026-27_CoverReport.pdf) |
| Total budget | **R87.71bn** (City page). Cape Argus reports R87.79bn | [City budget page](https://www.capetown.gov.za/Family%20and%20home/Meet-the-City/the-city-budget/the-citys-budget-2026-2027) · [Cape Argus](https://capeargus.co.za/news/2026-07-01-opposition-parties-reject-city-of-cape-towns-r8779bn-budget/) |
| Operating / capital | R74.62bn / R13.09bn (original) | [City budget page](https://www.capetown.gov.za/Family%20and%20home/Meet-the-City/the-city-budget/the-citys-budget-2026-2027) |
| Three-year capital (2026/27–2028/29) | R40bn | [CCT release 31 Mar 2026](https://www.capetown.gov.za/Media-and-news/Cape%20Town%20tables%20R40%20billion%20basic%20infrastructure%20budget%20to%20improve%20services%20to%20all) |
| Draft headline allocations | Water & sanitation R16.7bn (3 yr); grid R6bn (3 yr); safety R6.8bn; MyCiTi Cape Flats R3.3bn; informal settlements + housing R3.3bn; roads/stormwater R3.7bn; congestion relief R653m; sports facilities R227m; Strandfontein Pavilion R300m | same |
| Draft tariffs | Rates rate-in-rand −10.2% (new valuation roll); water & sanitation +4.5%; refuse +3.75%; city-wide cleaning +3.75%; electricity +6.67% average. Fixed-charge structure later amended after the court ruling | same |
| **Ward allocations** | **R1,000,000 per ward → R116,000,000** (Annexure 22 grand total) | [Annexure 22](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Financial%20documents/Budget-2026-27_Ann22.pdf) |
| Subcouncil operating allocations | R1,995,000 per subcouncil → R39,900,000 | [Annexure 24](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Financial%20documents/Budget-2026-27_Ann24.pdf) |
| CRR: ward allocations funded from 2025/26 savings | R51,701,084 | Covering report, recommendation 8 |
| Relief & charitable allocations | up to R22m | Covering report, recommendation 7 |
| Adjustments budgets | Aug 2026 and Oct 2026 adjustment packs are published | City budget page |

**Does CCT run participatory budgeting?** Not in the citizen-vote sense. The nearest equivalent is the **ward allocation**: about R1m per ward per year, spent on small projects proposed by the ward councillor with ward committee input and approved through the subcouncil. Examples include park upgrades, library books, neighbourhood-watch equipment, traffic calming, youth and seniors programmes, and CCTV. This makes a natural Decidim Budgets demo: **one budget per subcouncil = wards × R1,000,000**. This characterisation is mine and is based on Annexure 22 and the City's subcouncil page. The governing *Ward and Subcouncil Allocations Policy* was not re-read for 2026/27.

Sample real ward-allocation projects from Annexure 22 (proposed 2026/27). Amounts and ward attributions come from a PDF table extraction, so verify them before quoting:

| Ward | SC | Project | Rand |
|---|---|---|---|
| 23 | 1 | Traffic calming – Ward 23 | 252,850 |
| 23 | 1 | Beach Buddies – Ward 23 | 147,150 |
| 23 | 1 | Communication network improvement – Melkbosstrand NW | 300,000 |
| 23 | 1 | Wolwerivier informal trading zone – maintenance | 100,000 |
| 8 | 2 | Cox Park – upgrade | 250,000 |
| 28 | 4 | Elsies River Library – furniture | 150,000 |
| 44 | 11 | CCTV/LPR cameras – Ward 44 | 80,000 |
| 18 | 9 | Site C Stadium – upgrade | 50,000 |
| 39 | 13 | Nyanga initiation site – development | 100,000 |
| 14 | 14 | Kuils River Library – digital literacy programme | 50,000 |
| 66 | 18 | Ottery Library – outreach programme | 65,000 |
| 74 | 20 | Hout Bay Common – upgrade | 160,000 |

---

## 4. Meeting types and venues

| Meeting type | Cadence / format | Typical venue | Source |
|---|---|---|---|
| Subcouncil ordinary meeting | At least monthly except recess (usually school holidays). Open to the public and advertised in community papers | Subcouncil office (section 1.2) | [By-law s9](https://openbylaws.org.za/akn/za-cpt/act/by-law/2003/sub-council/eng@2024-08-30) · [Attend a subcouncil meeting](https://www.capetown.gov.za/City-Connect/Get-involved/attend/attend-a-subcouncil-meeting) |
| Ward committee meeting | At least 6 quorate meetings a year, none during recess. Open to residents | Community hall / library in the ward, or the subcouncil office | [Ward committee operation rules](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Procedures,%20guidelines%20and%20regulations/Rules%20-%20Operation%20of%20Ward%20Committees%20in%20the%20Metropolitan%20Area%20English.pdf) |
| Budget / IDP comment points | Documents on view and written comments accepted during comment windows | All subcouncil offices, all libraries, Civic Centre Concourse (Hertzog Blvd), Plumstead Municipal Offices | [2025/26 venues list](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Forms,%20notices,%20tariffs%20and%20lists/HYS_2025-26Budget_Venues_List.pdf) |
| Ward community engagement (feedback on approved projects) | Held per ward | Ward venues | [CCT wards page](https://www.capetown.gov.za/Family%20and%20home/Meet-the-City/city-council/wards) |
| Plan-specific open days / info sessions | Ad hoc. Examples: Kensington/Factreton LSDF open day (4 Oct 2025); heritage strategy virtual session (27 Aug 2026, 18:30–20:30) | Local hall or online | [CCT LSDF open day](https://www.capetown.gov.za/Media-and-news/City%20hosting%20Open%20Day%20about%20spatial%20vision%20for%20Kensington%20and%20Factreton%20areas) · [Heritage release](https://web1.capetown.gov.za/web1/newsandnotices/Home/Release/Comment-on-the-City-s-draft-Heritage-Resources-Management-Strategy) |
| Council meetings | Monthly calendar. Venue is the Civic Centre (Council Chamber), Hertzog Boulevard | Civic Centre | [Meeting calendar](https://www.capetown.gov.za/Family%20and%20home/Meet-the-City/City-Council/Meeting-calendar) |
| Upcoming (realistic demo timeline) | New Term of Office IDP 2027–32: community inputs Nov 2026–Mar 2027; draft IDP + 2027/28 budget tabled before 1 Apr 2027 for comment | Subcouncils / online | [IDP & Budget time-schedule 2026/27](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/City%20strategies,%20plans%20and%20frameworks/IDP-and-Budget-Time-Schedule_2026-27.pdf) |

---

## 5. Theme taxonomy (IDP 2022–2027): proposed Decidim categories

The vision is "City of Hope for all". The IDP has **6 priorities**, **3 foundations** and **16 objectives**. Sources: [IDP poster](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Graphics%20and%20educational%20material/IDP_2022-27_Poster.pdf) and [IDP 2022–27 summary](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/City%20strategies,%20plans%20and%20frameworks/IDP_2022-2027_Summary.pdf). Objective titles are verbatim headings. Their grouping under priorities is inferred from the numbering, so verify it.

| Category (priority / foundation) | Sub-categories (objectives) |
|---|---|
| Economic growth | 1 Increased jobs and investment in the Cape Town economy · 3 End load-shedding in Cape Town over time |
| Basic services | 2 Improved access to quality and reliable basic services · 4 Well-managed and modernised infrastructure |
| Safety | 5 Effective law enforcement to make communities safer · 6 Strengthen partnerships for safer communities |
| Housing | 7 Increased supply of affordable, well-located homes · 8 Safer, better-quality homes in informal settlements |
| Public space, environment and amenities | 9 Healthy and sustainable environment · 10 Clean and healthy waterways and beaches · 11 Quality and safe parks and recreation facilities supported by community partnerships |
| Transport | 12 A sustainable transport system that is integrated, efficient and provides safe and affordable travel options for all · 13 Safe and quality roads for pedestrians, cyclists and vehicles |
| *Foundation:* A resilient city | 14 |
| *Foundation:* A more spatially integrated and inclusive city | 15 |
| *Foundation:* A capable and collaborative city government | 16 |

There is an alternative operational taxonomy: the City's **directorates**, which it uses as Go Vocal topics. These are Water and Sanitation, Urban Waste Management, Urban Mobility, Spatial Planning and Environment, Safety and Security, Human Settlements, Energy, Economic Growth, Finance, Corporate Services, Community Services and Health, Future Planning and Resilience, and Office of the City Manager. Source: [Go Vocal topics API](https://capetown.govocal.com/web_api/v1/global_topics). Note that a **new 2027–2032 IDP** is being drafted, so the taxonomy will change in 2027.

---

## 6. Languages and glossary

- **Official languages:** English, Afrikaans and isiXhosa have equal status under the Western Cape Constitution and the Western Cape Provincial Languages Act 13 of 1998. The City's Language Policy (Policy no. 50554) lets residents deal with the City in any of the three. Sources: [CCT Language Policy PDF](https://resource.capetown.gov.za/documentcentre/Documents/Bylaws%20and%20policies/Language%20Policy%20-%20(Policy%20number%2050554)%20approved%20on%2025%20April%202018.pdf), [CCT release](https://www.capetown.gov.za/Media-and-news/City%20encourages%20residents%20to%20engage%20us%20in%20their%20mother%20language). Note: the PDF title says approved April 2018, while a search summary mentions a Nov 2021 version, which is unverified.
- By-laws and Council budget reports are published **trilingually**, with English prevailing on conflict. Heritage and other "Have Your Say" summaries are issued in en/af/xh.

| English | Afrikaans (CCT usage) | isiXhosa (CCT usage) | Evidence |
|---|---|---|---|
| ward / wards | wyk / wyke | iwadi / iiwadi | [Sub-council Amendment By-law 2024 (trilingual)](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Bylaws%20and%20policies/Sub-Council_Amendment_By-law_2024.pdf) |
| ward number(s) | wyksnommer(s) | — | same |
| ward councillor(s) | wyksraadslid / wyksraadslede | *not verified* | same (af only) |
| subcouncil / subcouncils | subraad / subrade | iBhungana / amaBhungana | same ("UMthetho kaMasipala … ongamaBhungana waseKapa") |
| Council | (die) Raad | iBhunga | same + [Budget covering report](https://www.capetown.gov.za/_documents/resource.capetown.gov.za/documentcentre/Documents/Financial%20documents/Budget-2026-27_CoverReport.pdf) |
| City of Cape Town | Stad Kaapstad | iSixeko saseKapa | same |
| by-law | verordening | umthetho kamasipala | by-law |
| budget | begroting | uhlahlo-lwabiwo-mali (spelled "uhlahlolwabiwomali" in source) | covering report |
| Integrated Development Plan (IDP) | geïntegreerde ontwikkelingsplan (IDP) | iSicwangciso soPhuhliso esiHlanganeneyo (IDP) | covering report |
| ward allocation(s) | wykstoewysing(s) | izabelo zewadi | covering report |
| annexure | bylae | isihlomelo | covering report |
| public participation / "Have your say" | *openbare deelname* (not verified in a CCT doc) | *not verified* | — |
| ward committee | *wykskomitee* (not verified) | *ikomiti yewadi* (not verified) | — |

Italic entries are my suggestions and **must be checked by a first-language speaker** before use. The isiXhosa text of the covering report contains at least one mistranslation: recommendation 12 says "ward allocations" where the English says "capital contingency fund". Treat even official translations with some care.

---

## Confidence & gaps

**High confidence:** the 20 subcouncils and their 2021-delimitation ward lists (official by-law, checked against the trilingual PDF and the parse); subcouncil office addresses (official 2025/26 list); Go Vocal item titles and dates (City's own platform API); the 2026/27 ward allocation of R1m per ward, R116m total (Annexure 22); the IDP priorities and objective titles; the adoption date and the R40bn three-year capital figure.

**Medium:** total budget (R87.71bn vs R87.79bn); draft allocation and tariff figures, which come from the March tabled release and were not re-checked against adopted annexures or the Aug/Oct 2026 adjustment budgets; department attribution for several items; objective-to-priority grouping.

**Top gaps / uncertainties**
1. **Post-election ward map.** The ODP shows 118 wards for 2026, but only Ward 117 is press-confirmed. Some existing wards may have been renumbered or redrawn, and no by-law yet assigns 117 and 118 to subcouncils. The SC1 and SC14 assignments are inferred spatially. A subcouncil by-law amendment is likely early in the new term.
2. **Subcouncil office addresses** come from the 2025/26 list. SC14 (Fezeka, Gugulethu) and SC17 (Lentegeur) look anomalous for their areas, so verify them against the Council Hub directory (web1.capetown.gov.za/web1/councilhubonline, which did not render for automated fetch).
3. **ODP licence:** the terms are "no remuneration, as-is" with no named open licence. Confirm that redistributing derived GeoJSON in a public demo is allowed.
4. **Go Vocal project descriptions** were not exposed by the API, so summaries for items 3, 7, 10, 13, 16, 17 and 19–24 are thin and title-derived. Read the linked pages before using them as long-form demo text.
5. **No 2025–26 Integrated Resource Plan/energy consultation and no authoritative MURP precinct list** were found. Use budget lines for those themes instead.
6. **isiXhosa/Afrikaans terms for "public participation", "ward committee" and "ward councillor" (xh)** are unverified.
7. Resource host `resource.capetown.gov.za` timed out from this environment. The same files were fetched through `www.capetown.gov.za/_documents/resource.capetown.gov.za/...`, and both URL forms are cited.
8. Election results of 4 Nov 2026 were deliberately not collected, because they are not needed and are not final.
