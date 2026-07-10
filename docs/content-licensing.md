# Content licensing — Bible text

This app ships Scripture text embedded in its own database (offline-first). That
makes the **licensing of each translation a shipping-blocker concern**, not a
detail: embedding and redistributing copyrighted Bible text without a license is
copyright infringement, and it scales with our user count.

This note records what we ship, the license status of each source, and what must
be resolved before a commercial / at-scale launch.

## What we ship today

| Version | Code | Lang | Verses | Canon | Source | License status | Commercial-safe? |
|---------|------|------|-------:|-------|--------|----------------|:----------------:|
| King James Version | `kjv` | en | 31,102 | Full 66 (OT+NT) | eBible.org `eng_kjv` | **Public domain** | ✅ Yes |
| Amharic Bible | `amh` | am | 31,014 | Full 66 (OT+NT) | WordProject (`am_new`) | **Non-commercial only** | ⚠️ **No — must resolve** |
| NIV | `niv` | en | 0 (metadata only) | — | — | `requires_license` | ✅ Not embedded (gated) |

The `license_status` column in `bible_versions` drives behavior: `requires_license`
returns a notice instead of text (that's why NIV is safe — we never embedded it).
`kjv` is `available` (public domain). `amh` is now `non_commercial`, which the
API still serves for the MVP but is flagged here for follow-up.

## The Amharic OT problem

The Amharic text (`amh`) — **including the full Old Testament** — comes from
**WordProject (wordproject.org)**, whose terms grant **personal, non-commercial
use only**. That is acceptable for an internal MVP / demo, but it is **not
cleared for a commercial launch, a paid product, or large-scale public
distribution.**

Separately, the widely used **1962 Amharic Bible (አዲሱ መደበኛ ትርጉም and the
haile-sellassie-era standard) is under Bible Society of Ethiopia copyright** and
also may not be embedded without a license. So we cannot simply swap in "the
standard Amharic Bible" either — that carries the same problem.

WordProject also asks that the text be **credited**; the app surfaces the
`copyright_notice` for that reason. Attribution alone does **not** upgrade the
license to commercial use.

## Options to clear Amharic for commercial launch

Pick one before shipping commercially. Roughly in order of preference:

1. **License from the Bible Society of Ethiopia (BSE) / United Bible Societies.**
   The proper, durable path for the standard Amharic translations (1962 and the
   newer መደበኛ ትርጉም). Involves a licensing agreement and likely per-user or flat
   fees. Contact BSE directly.

2. **Use a licensed API instead of embedding** — e.g. the **Digital Bible
   Library / API.Bible (American Bible Society)** or **YouVersion/Bible.com**
   partner access. These let us *display* licensed translations under their terms
   without redistributing the raw text in our own DB. Trade-off: weakens the
   offline-first story unless the API license permits caching.

3. **Ship an openly-licensed Amharic translation.** Check **eBible.org** and
   **unfoldingWord/Door43** for an Amharic translation released under Public
   Domain or a Creative Commons license (e.g. CC BY-SA / CC0). `import-bible.js`
   already references an eBible.org Amharic NT; a genuinely open, full-canon
   Amharic edition would be the cleanest embed-friendly answer if one exists.

4. **Keep WordProject but obtain written commercial permission.** Email
   WordProject and ask for explicit permission for our use case in writing. Least
   reliable; depends on their goodwill and does not obviously cover a paid app.

## Action items (before commercial launch)

- [ ] Decide the Amharic licensing path (option 1–4 above) and record the
      decision in `docs/implementation-decisions.md`.
- [ ] If licensed/replaced: re-import via the matching script, update
      `bible_versions.copyright_notice` + `license_status`, and keep the required
      attribution string in the reader UI.
- [ ] If not resolved in time: gate `amh` the same way as NIV (set
      `license_status='requires_license'`) so full text is not served, or restrict
      the app to KJV until Amharic is cleared. **Do not launch commercially while
      `amh` serves WordProject text.**
- [ ] Keep KJV (`kjv`) — public domain, no action needed.
- [ ] NIV (`niv`) stays metadata-only unless a publisher license is signed.

## Attribution shown in-app

- **KJV:** "Public domain."
- **Amharic:** "Amharic Holy Bible, courtesy of WordProject (wordproject.org).
  Free for personal, non-commercial use only."
