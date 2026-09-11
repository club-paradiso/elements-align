# Product

## What this is

**Elements, Align.** is a location-, direction-, time- and person-aware ambient
Apple Watch experience drawn from East Asian traditional cosmology.

It is not a horoscope app. The difference is the whole product.

## The feeling to build for

Not this:

> The universe says you must sit here.

This:

> This place seems to fit me right now.

Everything else follows from that distinction. It is why unfavourable
directions are compressed rather than punished, why falling transitions are
silent, why the brand phrase appears once and only at full alignment, and why
the score is secondary to the state name.

## The interaction

A wearer turns their body. The watch responds continuously:

    Quiet → Unsettled → Neutral → Favourable → Strong → Aligned

As they approach a personally favourable direction the composition organises
itself. At full alignment the elements converge, a restrained haptic fires
once, and the brand phrase appears.

Reaching `Aligned` needs the confluence the product is named for: facing your
生氣 direction *and* a moment made of your favourable elements. Facing the
perfect direction on an ordinary day reaches `Strong`, not `Aligned`. That is
deliberate — alignment should be worth noticing.

## Tone

**Avoided:** dragons, gold, red-and-gold restaurant aesthetics, crowded bagua
graphics, mystical gradients, fortune-cookie language, slot-machine results,
"GOOD LUCK!!!".

**Aimed for:** minimal, calm, mysterious, spatial, premium, contemporary,
Apple-native, culturally respectful.

The experience should work for someone who does not literally believe in
fortune telling. It is offered as a way of noticing, not a verdict.

## What it will not claim

Alignment is a **deterministic symbolic score produced from selected
traditional cosmological rules and current contextual inputs**. It is never
presented as:

- a measured energy field
- a health or psychological assessment
- a guaranteed prediction
- financial, safety or medical advice
- deterministic fate

The interface does not lecture about this. Onboarding, Settings and About
carry it plainly, once.

## Language

US-facing vocabulary leads; technical terms follow:

| Concept | Primary | Secondary |
| --- | --- | --- |
| 八字 | Four Pillars | BaZi |
| 五行 | Five Elements | Wu Xing |
| 風水 | Feng Shui | — |
| 八宅 | Your directions | Eight Mansions / Ba Zhai |

Nobody should have to learn Chinese terminology before the product becomes
useful to them. The characters are shown alongside, not instead.

The eight Eight Mansions relationships are given plain-English names in the
interface — Vitality, Restoration, Continuity, Stillness, Friction, Drift,
Distraction, Depletion — which keep the traditional ranking without importing
the ominous framing of literal translations like "Disaster" or "Severed Fate".

English and Korean ship from the start.

## Scope

### V1 — Directional Alignment Prototype

A compelling working Apple Watch prototype, not an App Store-complete
platform. Four Pillars, Five Elements, Eight Mansions. Live heading. Reactive
composition. Restrained haptics. iPhone onboarding and profile.

### Explicitly not in V1

Western astrology, Zi Wei Dou Shu, Thai astrology, tarot, numerology,
generative-AI interpretation, Xuan Kong Flying Stars.

### The long-term question

> Where should I sit in this room?

A wearer enters a café. Their iPhone briefly understands the space. Candidate
seats receive symbolic scores. The phone goes away, and the watch guides them
by direction, motion and haptic intensity.

That is the destination. V1 does not depend on indoor positioning to get
there, and does not pretend GPS could do it — it is nowhere near accurate
enough for chair-level placement.

## Privacy as a product property

Birth details and location are the most sensitive things this product touches.
They stay on the device. No account, no sync, no analytics carrying them, no
server-side calculation, and no part of any result from an AI service.

This is not only an ethical position, it is a design constraint that shaped
the code: the offline birth-place table exists because geocoding a birth city
would have made the claim untrue.
