# Privacy

## The claim

Birth details and location never leave the device.

That is a strong claim, so here is exactly what backs it.

## What is collected

| Data | Why | Where it goes |
| --- | --- | --- |
| Birth date | Four Pillars | `UserDefaults`, this device |
| Birth time, or an explicit "unknown" | Hour pillar | `UserDefaults`, this device |
| Birth longitude | Solar time at the place of birth | `UserDefaults`, this device |
| Polarity (yang/yin) | Eight Mansions life gua | `UserDefaults`, this device |
| Compass heading | The interaction itself | Memory only, never persisted |

Latitude is stored but unused by V1; it exists for future spatial work.

## What is not collected

No name, email or account. No contacts, photos, health or motion data. No
device or advertising identifiers. No analytics or crash-reporting SDK. No
position fix at all in the default magnetic-heading mode.

## Where the calculation happens

Entirely on device, in `ElementsCore`, which imports Foundation and nothing
else — no networking, by construction.

**The app makes no network requests.** There is no backend, and no third-party
dependency of any kind that could make one.

## No AI in the calculation

No part of any result comes from a language model. Calendar conversion, Four
Pillars, Five Elements, Eight Mansions and Alignment are all deterministic
code. An LLM may eventually help *explain* a result conversationally; it will
never be where the result comes from.

## Design decisions this forced

The claim is not a policy bolted on afterwards — it changed the code.

**Birth places come from an offline table.** The obvious implementation is to
geocode a city name. That would send someone's birth city to a third party in
order to look up a value that only needs to be accurate to about a degree, and
it would make the claim above untrue. `Apps/Shared/BirthPlace.swift` ships a
small table instead, with manual longitude entry for everywhere it misses. The
experience is worse; the trade was made knowingly and is recorded on the
roadmap.

**Magnetic heading is the default.** True heading requires Core Location to
know where the device is. Magnetic does not. It also happens to match luopan
practice, so the privacy-preserving default is the traditionally correct one.

## Permissions

One: location, when in use. iOS groups compass access under location
permission even though no position fix is needed. The usage description says
so plainly:

> Elements, Align. uses the compass to tell which way you are facing. Your
> position is never stored or sent anywhere.

Denial is a supported state, not an error. The app runs, and the spatial
component falls back to neutral.

## Deletion

Settings → Delete my data removes everything, immediately, on device. No
request to anyone, nothing to wait for, nothing retained elsewhere — there is
nowhere else for it to be.

## Positioning

The interface does not lecture. Onboarding, Settings and About carry this once,
plainly, alongside the statement that Alignment is a symbolic value from
traditional rules rather than a measurement of anything physical.
