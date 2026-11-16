# CraveCircle legal-page drafts

**Status: draft for founder and qualified legal review before publishing.** This document is not legal advice.
It is written from the current implementation: imported recipes are private to the importing user,
and the app preserves a link back to the original source where one was supplied.

The public website routes remain:

- `https://cravecircle.cc/privacy`
- `https://cravecircle.cc/terms`
- `https://cravecircle.cc/support`

Before publishing, replace every bracketed placeholder with a real legal entity, address, support
email, governing jurisdiction, and effective date. Do not claim that a feature is deployed until
the website pages and the accompanying operational controls are live.

---

## Privacy Policy draft

**Effective date: [DATE]**

CraveCircle is a recipe-organising app provided by **[LEGAL ENTITY]** (“CraveCircle”, “we”, “us”).
This Privacy Policy explains how the CraveCircle iOS app handles information.

### What we process

CraveCircle processes the information needed to provide the features you choose to use:

- Account information, such as email address and basic profile details, if you create an account.
- Recipes, grocery lists, collections, comments, and recipe photos you intentionally create or save.
- A recipe link you intentionally paste or share for import.
- The recipe text, ingredient list, directions, and nutrition estimate created from an import.

### Cooking-media imports

When you import a link, CraveCircle sends the link to its self-hosted import relay so it can obtain
the selected public cooking post, extract food-related recipe information, and return a structured
recipe to your device. The relay uses temporary working media only for processing. It does not
retain a public video or audio library and imported recipes are not added to the community catalog.

An import result is a private hand-off: once the importing app fetches the structured recipe, the
relay removes the temporary result and associated job record. If delivery is interrupted, the
temporary result remains only until it can be retrieved or is cleared under the service's retention
controls. Your imported recipe stays in your private library; it cannot be published or shared to
other CraveCircle users. Where the source link is available, the **Watch** control opens that
original source.

For an on-device import, speech transcription and on-screen text recognition run on the phone where
supported. The app does not upload a locally selected cooking video merely to perform on-device
transcription. Temporary local media used for processing is discarded after the import flow.

### Device permissions

- **Camera:** used for optional hands-free cooking gestures; frames are processed on device and are
  not recorded or transmitted by CraveCircle.
- **Microphone and Speech Recognition:** used for optional voice controls and, where available,
  on-device transcription. CraveCircle does not create a voice recording library.
- **Photo Library:** used only for the recipe photo or cooking media you select. A photo you choose
  as a recipe cover remains with that recipe; a processing-only video is not kept as a library item.

### How we use information

We use this information to operate your private library, render recipe details, calculate optional
nutrition estimates, provide account and support functions, and maintain service security. We do
not sell personal information, run advertising, use cross-app tracking, or include third-party
analytics SDKs for behavioural advertising.

### Service providers and disclosures

We use our self-hosted backend to process link imports and Supabase services for account and data
functions where enabled. We may disclose information when required by law or to protect the service,
users, or others. We do not provide imported cooking media as a public dataset or public feed.

### Retention and deletion

You can delete a locally stored recipe from the app. To request account or backend-content deletion,
contact **[SUPPORT EMAIL]**. We retain only what is reasonably necessary to operate the service,
resolve issues, meet legal obligations, and enforce these terms. Temporary import artifacts are
handled as described above.

### Children, rights, changes, and contact

CraveCircle is not directed to children under 13. Depending on your location, you may have rights
to request access, correction, deletion, or information about processing; contact **[SUPPORT EMAIL]**.
We may update this policy and will post the revised effective date here. Contact: **[LEGAL ENTITY,
POSTAL ADDRESS, SUPPORT EMAIL]**.

---

## Terms of Service draft

**Effective date: [DATE]**

By using CraveCircle, you agree to these Terms. If you do not agree, do not use the service.

### Accounts and acceptable use

You are responsible for your account and for using CraveCircle lawfully. Do not attempt to access
another person's account, interfere with the service, upload harmful material, or infringe another
person's rights.

### Recipe imports and third-party sources

You may import only content that you are permitted to access and process, and you remain responsible
for complying with the source platform's terms and applicable law. CraveCircle extracts structured,
food-related recipe information from a link you provide. It does not grant you rights in the source
video, audio, images, creator identity, or other third-party content.

Imported recipes are private library references. They cannot be published to the CraveCircle catalog
or shared with another CraveCircle account. Use the **Watch** control to return to the original
source when available. Only original recipes created in Studio and eligible under the app's rules
may be submitted for publication.

### Your content

You retain ownership of original content you create. You grant us the limited rights necessary to
store, display, and transmit that content solely to operate CraveCircle. You must not submit content
that is unlawful, defamatory, harmful, or infringing. We may remove or restrict content or accounts
that violate these Terms or create a safety, legal, or operational risk.

### Nutrition and cooking safety

Nutrition values are automatic estimates based on extracted ingredient text. They can be incomplete
or inaccurate and are not medical, dietary, allergy, or professional nutritional advice. Check
allergens, ingredient safety, cooking temperatures, and recipe suitability yourself.

### Disclaimers and liability

CraveCircle is provided on an “as is” and “as available” basis to the extent permitted by law. We do
not guarantee that an import will work, that a recipe is complete or safe, or that third-party links
will remain available. To the maximum extent permitted by law, **[LEGAL ENTITY]** is not liable for
indirect, incidental, special, consequential, or punitive damages arising from use of the service.

### Suspension, changes, governing law, and contact

We may suspend or terminate access for violations, security concerns, or service changes. We may
update these Terms by posting an updated effective date. These Terms are governed by the laws of
**[JURISDICTION]**, subject to applicable consumer protections. Contact: **[LEGAL ENTITY, POSTAL
ADDRESS, SUPPORT EMAIL]**.

---

## Support page draft

**Need help?** Contact **[SUPPORT EMAIL]**. We aim to respond within **[RESPONSE TIME]**.

### Frequently asked questions

**How does a link import work?** You choose a recipe link. CraveCircle processes it into recipe text
and sends the result to your private library. The imported recipe is not publicly published.

**Does CraveCircle keep the source video or audio?** The import relay uses temporary working media
to process the link. It does not operate a public media archive. The structured result is removed
from the relay after delivery to the app; see the Privacy Policy for interrupted-delivery handling.

**Can I share an imported recipe?** No. Imported recipes are private references. Use **Watch** to
open the original source where available.

**How do I delete a recipe or my account?** Delete a locally stored recipe from the app. For account
or backend-content requests, email **[SUPPORT EMAIL]**.

Read our [Privacy Policy](/privacy) and [Terms of Service](/terms).

---

## Pre-publication checklist

- Obtain legal review for the jurisdiction, entity, and consumer-law wording.
- Add a real monitored support address and postal address.
- Deploy matching `/privacy`, `/terms`, and `/support` website pages and verify each returns 200.
- Confirm the import relay's retention job and deletion logging are deployed before claiming the
  temporary-result deletion behavior in the public policy.
- Add the final privacy and support URLs to App Store Connect.
