# Objectives

I want to expand the objective system for my game, which involves parody names of common stores.

"Mats Darling, while you're out exploring, could you pick up some cough syrup at Walgroins?"

Under the new system: some of the buidings in the game have items associated with them.

Walgroins -> [cough syrup, band-aids, potato chips, toothpaste, batteries]
Booger King -> [hamburgers]
Taco Hell -> [tacos, burritos, quesadillas]
Smell -> [milk, cereal, chewing gum, beef jerkey].

I also want her to sometimes use the generic name instead of specific. Eg, "the pharmacy" instead of Walgroins, "The convenience store" instead of Smell.

So there are multiple stock openings. They sometimes use dutch words.

- "Hi Mats, are you having fun out there?"
- "Mats Schat ["Little treasure"]...
- "mats M’n jongen ["My boy"]...

There are multiple excuses that could be used:

- "I don't feel like cooking dinner tonight."
- "I just remembered another thing!"
- "Could you grab one more item for your mother?"

Then an item and store.

## Eg,

```json
{
  "dialogue_parts": {
    "openings": ["Hi Mats, are you having fun out there?", "Mats schat...", "Mats, m’n jongen..."],
    "excuses": [
      "I don't feel like cooking dinner tonight.",
      "I just remembered another thing!",
      "Could you grab one more item for your mother?"
    ],
    "requests": [
      "Could you pick up some {item} at {location}?",
      "Can you stop by {location} and get some {item}?",
      "While you're out, swing by {location} for some {item}."
    ]
  },
  "locations": [
    {
      "id": "walgroins",
      "proper_name": "Walgroins",
      "generic_name": "the pharmacy",
      "items": ["cough syrup", "band-aids", "potato chips", "toothpaste", "batteries"]
    },
    {
      "id": "booger_king",
      "proper_name": "Booger King",
      "generic_name": "the burger joint",
      "items": ["hamburgers"]
    },
    {
      "id": "taco_hell",
      "proper_name": "Taco Hell",
      "generic_name": "the taco stand",
      "items": ["tacos", "burritos", "quesadillas"]
    },
    {
      "id": "smell",
      "proper_name": "Smell",
      "generic_name": "the convenience store",
      "items": ["milk", "cereal", "chewing gum", "beef jerky"]
    }
  ]
}
```
