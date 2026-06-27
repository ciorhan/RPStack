# First Arrival Product Brief

## Status

Accepted product direction. Implementation has not started.

This document defines the target player experience for Frontier Hegemony and
the first vertical slice RPStack will deliver. It is a product contract, not a
technical design. Architecture decisions must continue to follow RPStack's
server-authoritative boundaries and module ownership rules.

## Product direction

Frontier Hegemony is a fictional 1890s frontier built for accessible, serious
roleplay. New players should be able to participate without prior RedM
experience, while believable characters, cooperation, and long-term stories
remain more valuable than mechanical grinding.

The setting is historically grounded without requiring strict historical
simulation. "Hegemony" means influence over trade, law, politics, reputation,
and eventually territory. Territorial control is a consequence of player
activity, not a standalone map-painting game.

## Player promise

> Arrive as nobody. Build relationships, reputation, and influence. Leave a
> mark the territory remembers.

Systems should create reasons for players to need, meet, remember, and respond
to one another. Activities that produce currency but no relationships or
decisions are supporting content, not the core experience.

## Retention principles

The experience should reinforce:

1. **Belonging** - other characters recognize and need the player.
2. **Agency** - players can pursue their own plans without choosing a fixed
   class or faction.
3. **Progress** - characters develop socially and materially.
4. **Consequences** - meaningful actions change later opportunities.
5. **Anticipation** - players finish a session with a reason to return.
6. **Fairness** - progress is not controlled by pay-to-win systems, excessive
   grinding, staff favoritism, or hidden rules.

## First Arrival

First Arrival is the initial connect-to-open-world experience. It combines
character selection, character creation, appearance, a narrative arrival, and
one personal lead.

Character creation is an **Arrival Story**, not a character build. It asks:

| Decision | Purpose |
| --- | --- |
| Name and age | Establish legal identity |
| Appearance | Establish visual identity |
| Origin | Provide personal context and dialogue material |
| Reason for arrival | Establish the character's immediate motivation |
| Past trade | Suggest plausible introductory opportunities |
| Principle | Give the player a roleplay prompt |
| Unresolved burden | Create an optional long-term story hook |
| Arrival point | Frame the opening scene |

These choices may change starting context, documents, modest equipment, and
available leads. They must not grant permanent statistical advantages or
create an optimal background.

## First-session outcome

A new character should enter the world with:

- a modest, balanced starter kit;
- a physical letter, contract, warrant, clipping, or comparable story object;
- one clear destination or person to seek;
- two or three visible ways to earn an initial living;
- an optional connection to a player, business, or faction;
- enough context to roleplay without reading an external guide.

The opening should teach interaction through play. It must not force a job,
faction, permanent allegiance, or lengthy tutorial.

## Player journey

| Period | Intended experience |
| --- | --- |
| First 15 minutes | Create a character and complete the arrival |
| First session | Follow a personal lead and learn the basic interactions |
| First week | Find work, relationships, and a local community |
| First month | Build reputation, property, a business, or faction standing |
| Long term | Influence laws, markets, settlements, conflicts, and history |
| Return after absence | Understand what changed and find a new reason to act |

## First playable slice

The first release targets one settlement as a complete social ecosystem rather
than a shallow version of the whole map. The specific settlement remains a
separate design decision.

The slice should contain:

- one arrival point and safe initial spawn;
- one registry, hotel, or equivalent orientation location;
- a general store, saloon, sheriff, and doctor;
- two mobile odd jobs that encourage exploration;
- one legal supply chain;
- one illegal opportunity with meaningful risk;
- personal leads;
- local reputation;
- at least one reason for players in different roles to trade or cooperate.

Factions should create opportunities for unaffiliated players. A hunter,
merchant, deputy, doctor, laborer, or drifter must remain viable without formal
faction membership.

## MVP boundaries

First Arrival includes:

- reliable connection, character selection, creation, selection, and spawn;
- one complete appearance flow, whether integrated or owned by RPStack;
- server validation and persistence of authoritative character data;
- one cinematic or in-world arrival sequence;
- one generated personal lead;
- recovery from interrupted creation without duplicating characters or rewards;
- a clear path back to character selection after reconnecting.

First Arrival does not include:

- a custom facial-customization engine when a suitable integration is
  available;
- permanent background perks or skill trees;
- mandatory faction selection;
- a complete profession system;
- player housing;
- territory conquest;
- a map-wide economy;
- dozens of jobs or scripted tutorials.

## Experience constraints

- A first-time player should reach the open world in roughly 15 minutes.
- Returning players should bypass creation and resume quickly.
- Appearance should remain adjustable during an initial grace period.
- Destructive actions, including character deletion, require explicit
  confirmation and server-side authorization.
- Creation rewards must be issued exactly once.
- Client-provided identity, appearance, background, and spawn data are
  requests; the server validates and persists the accepted state.
- A failed or disconnected creation flow must be resumable or safely
  restartable.

## Success criteria

The vertical slice is successful when a test player can:

1. Connect without becoming stuck in loading.
2. Create a meaningful character without external instructions.
3. Enter the world with correct persisted identity and appearance.
4. Understand where they are and identify a next action.
5. Follow a personal lead during the first session.
6. Meet, trade with, or cooperate with another character.
7. Disconnect and return without losing or duplicating state.
8. Finish with a clear reason to play another session.

Technical completion alone is insufficient. Closed-alpha observation must show
that players understand the flow and begin creating roleplay without staff
walking each person through it.

## Delivery order

1. Establish a reliable connect-to-spawn path with a temporary test character.
2. Add character selection and the minimum validated creation contract.
3. Add or integrate appearance.
4. Add the Arrival Story decisions and persistence.
5. Add the opening sequence and first personal lead.
6. Build the single-settlement first-session loop.
7. Test with a small recurring closed-alpha group before expanding scope.

## Product guardrails

Do not optimize the design around:

- long economic grinds;
- mandatory faction membership;
- permanent advantages selected during creation;
- large rulebooks required before play;
- staff-created main characters;
- constant combat as the primary source of excitement;
- repetitive prompt loops presented as professions;
- forced character death as a routine consequence;
- breadth of scripts instead of depth of interaction.

When a proposed feature does not strengthen belonging, agency, progression,
consequences, anticipation, or fairness, it should not displace work on the
first playable slice.
